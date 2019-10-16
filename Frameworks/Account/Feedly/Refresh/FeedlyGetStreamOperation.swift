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

protocol FeedlyGetStreamOperationDelegate: class {
	func feedlyGetStreamOperation(_ operation: FeedlyGetStreamOperation, didGet stream: FeedlyStream)
}

/// Single responsibility is to get the stream content of a Collection from Feedly.
final class FeedlyGetStreamOperation: FeedlyOperation, FeedlyEntryProviding {
	
	struct ResourceProvider: FeedlyResourceProviding {
		var resource: FeedlyResourceId
	}
	
	let resourceProvider: FeedlyResourceProviding
	
	var resource: FeedlyResourceId {
		return resourceProvider.resource
	}
	
	var entries: [FeedlyEntry] {
		guard let entries = storedStream?.items else {
			assert(isFinished, "This should only be called when the operation finishes without error.")
			assertionFailure("Has this operation been addeded as a dependency on the caller?")
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
	let continuation: String?
	
	weak var streamDelegate: FeedlyGetStreamOperationDelegate?
	
	init(account: Account, resource: FeedlyResourceId, caller: FeedlyAPICaller, continuation: String? = nil, newerThan: Date?, unreadOnly: Bool? = nil) {
		self.account = account
		self.resourceProvider = ResourceProvider(resource: resource)
		self.caller = caller
		self.continuation = continuation
		self.unreadOnly = unreadOnly
		self.newerThan = newerThan
	}
	
	convenience init(account: Account, resourceProvider: FeedlyResourceProviding, caller: FeedlyAPICaller, newerThan: Date?, unreadOnly: Bool? = nil) {
		self.init(account: account, resource: resourceProvider.resource, caller: caller, newerThan: newerThan, unreadOnly: unreadOnly)
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		caller.getStream(for: resourceProvider.resource, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly) { result in
			switch result {
			case .success(let stream):
				self.storedStream = stream
				
				self.streamDelegate?.feedlyGetStreamOperation(self, didGet: stream)
				
				self.didFinish()
				
			case .failure(let error):
				self.didFinish(error)
			}
		}
	}
}
