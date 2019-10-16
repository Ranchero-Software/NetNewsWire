//
//  FeedlyOrganiseParsedItemsByFeedOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import os.log

protocol FeedlyParsedItemsByFeedProviding {
	var providerName: String { get }
	var parsedItemsKeyedByFeedId: [String: Set<ParsedItem>] { get }
}

/// Single responsibility is to group articles by their feeds.
final class FeedlyOrganiseParsedItemsByFeedOperation: FeedlyOperation, FeedlyParsedItemsByFeedProviding {
	private let account: Account
	private let entryProvider: FeedlyEntryProviding
	private let log: OSLog
	
	var parsedItemsKeyedByFeedId: [String : Set<ParsedItem>] {
		assert(Thread.isMainThread) // Needs to be on main thread because Feed is a main-thread-only model type.
		return itemsKeyedByFeedId
	}
	
	var providerName: String {
		return entryProvider.resource.id
	}
	
	private var itemsKeyedByFeedId = [String: Set<ParsedItem>]()
	
	init(account: Account, entryProvider: FeedlyEntryProviding, log: OSLog) {
		self.account = account
		self.entryProvider = entryProvider
		self.log = log
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else { return }
		
		let items = entryProvider.parsedEntries
		var dict = [String: Set<ParsedItem>](minimumCapacity: items.count)
		
		for item in items {
			let key = item.feedURL
			let value: Set<ParsedItem> = {
				if var items = dict[key] {
					items.insert(item)
					return items
				} else {
					return [item]
				}
			}()
			dict[key] = value
			
			guard !isCancelled else { return }
		}
		
		os_log(.debug, log: log, "Grouped %i items by %i feeds for %@", items.count, dict.count, entryProvider.resource.id)
		
		itemsKeyedByFeedId = dict
	}
}
