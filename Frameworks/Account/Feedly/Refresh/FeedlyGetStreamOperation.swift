//
//  FeedlyGetStreamOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser

protocol FeedlyEntryProviding: class {
	var resource: FeedlyResourceId { get }
	var entries: [FeedlyEntry] { get }
	var parsedEntries: Set<ParsedItem> { get }
}

/// Single responsibility is to get the stream content of a Collection from Feedly.
final class FeedlyGetStreamOperation: FeedlyOperation, FeedlyEntryProviding {
	
	private(set) var resource: FeedlyResourceId
	
	var entries: [FeedlyEntry] {
		guard let entries = storedStream?.items else {
			assertionFailure("Has a prior operation finished too early? Is the operation included in \(self.dependencies)?")
			return []
		}
		return entries
	}
	
	var parsedEntries: Set<ParsedItem> {
		if let entries = storedParsedEntries {
			return entries
		}
		
		let parsed = Set(entries.map { FeedlyEntryParser(entry: $0).parsedItemRepresentation })
		storedParsedEntries = parsed
		
		return parsed
	}
	
	private var storedStream: FeedlyStream? {
		didSet {
			storedParsedEntries = nil
		}
	}
	
	private var storedParsedEntries: Set<ParsedItem>?
	
	
	let account: Account
	let caller: FeedlyAPICaller
	let unreadOnly: Bool?
	let newerThan: Date?
	
	init(account: Account, resource: FeedlyResourceId, caller: FeedlyAPICaller, newerThan: Date?, unreadOnly: Bool? = nil) {
		self.account = account
		self.resource = resource
		self.caller = caller
		self.unreadOnly = unreadOnly
		self.newerThan = newerThan
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		caller.getStream(for: resource, newerThan: newerThan, unreadOnly: unreadOnly) { result in
			switch result {
			case .success(let stream):
				self.storedStream = stream
				self.didFinish()
			case .failure(let error):
				self.didFinish(error)
			}
		}
	}
}
