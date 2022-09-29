//
//  FeedlyGetEntriesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

/// Get full entries for the entry identifiers.
final class FeedlyGetEntriesOperation: FeedlyOperation, FeedlyEntryProviding, FeedlyParsedItemProviding, Logging {

	let account: Account
	let service: FeedlyGetEntriesService
	let provider: FeedlyEntryIdentifierProviding

	init(account: Account, service: FeedlyGetEntriesService, provider: FeedlyEntryIdentifierProviding) {
		self.account = account
		self.service = service
		self.provider = provider
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
		
		if parsed.count != entries.count {
			let entryIds = Set(entries.map { $0.id })
			let parsedIds = Set(parsed.map { $0.uniqueID })
			let difference = entryIds.subtracting(parsedIds)
            self.logger.debug("\(String(describing: self), privacy: .public) dropping articles with ids: \(difference)).")
		}
		
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
                self.logger.error("Unable to get entries: \(error.localizedDescription, privacy: .public)")
				self.didFinish(with: error)
			}
		}
	}
}
