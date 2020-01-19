//
//  FeedlyGetEntriesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser

/// Get full entries for the entry identifiers.
final class FeedlyGetEntriesOperation: FeedlyOperation, FeedlyEntryProviding, FeedlyParsedItemProviding {

	let account: Account
	let service: FeedlyGetEntriesService
	let provider: FeedlyEntryIdentifierProviding
	let log: OSLog

	init(account: Account, service: FeedlyGetEntriesService, provider: FeedlyEntryIdentifierProviding, log: OSLog) {
		self.account = account
		self.service = service
		self.provider = provider
		self.log = log
	}
	
	private (set) var entries = [FeedlyEntry]()
	
	private var storedParsedEntries: Set<ParsedItem>?
	
	var parsedEntries: Set<ParsedItem> {
		if let entries = storedParsedEntries {
			return entries
		}
		
		let parsed = Set(entries.compactMap {
			FeedlyEntryParser(entry: $0).parsedItemRepresentation
		})
		
		// TODO: Fix the below. There’s an error on the os.log line: "Expression type '()' is ambiguous without more context"
//		if parsed.count != entries.count {
//			let entryIds = Set(entries.map { $0.id })
//			let parsedIds = Set(parsed.map { $0.uniqueID })
//			let difference = entryIds.subtracting(parsedIds)
//			os_log(.debug, log: log, "%{public}@ dropping articles with ids: %{public}@.", self, difference)
//		}
		
		storedParsedEntries = parsed
		
		return parsed
	}
	
	var parsedItemProviderName: String {
		return name ?? String(describing: Self.self)
	}
	
	override func run() {
		service.getEntries(for: provider.entryIds) { result in
			switch result {
			case .success(let entries):
				self.entries = entries
				self.didFinish()
				
			case .failure(let error):
				os_log(.debug, log: self.log, "Unable to get entries: %{public}@.", error as NSError)
				self.didFinish(with: error)
			}
		}
	}
}
