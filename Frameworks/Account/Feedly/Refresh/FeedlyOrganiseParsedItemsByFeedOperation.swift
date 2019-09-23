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
	var collection: FeedlyCollection { get }
	var stream: FeedlyStream { get }
	var allFeeds: Set<Feed> { get }
	func parsedItems(for feed: Feed) -> Set<ParsedItem>?
}

/// Single responsibility is to group articles by their feeds.
final class FeedlyOrganiseParsedItemsByFeedOperation: FeedlyOperation, FeedlyParsedItemsByFeedProviding {
	private let account: Account
	private let parsedItemsProvider: FeedlyStreamParsedItemsProviding
	private let log: OSLog
	
	var allFeeds: Set<Feed> {
		let keys = Set(itemsKeyedByFeedId.keys)
		return account.flattenedFeeds().filter { keys.contains($0.feedID) }
	}
	
	func parsedItems(for feed: Feed) -> Set<ParsedItem>? {
		return itemsKeyedByFeedId[feed.feedID]
	}
	
	var collection: FeedlyCollection {
		return parsedItemsProvider.collection
	}
	
	var stream: FeedlyStream {
		return parsedItemsProvider.stream
	}
	
	private var itemsKeyedByFeedId = [String: Set<ParsedItem>]()
	
	init(account: Account, parsedItemsProvider: FeedlyStreamParsedItemsProviding, log: OSLog) {
		self.account = account
		self.parsedItemsProvider = parsedItemsProvider
		self.log = log
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else { return }
		
		let items = parsedItemsProvider.parsedItems
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
		
		os_log(.debug, log: log, "Grouped %i items by %i feeds for %@", items.count, dict.count, parsedItemsProvider.collection.label)
		
		itemsKeyedByFeedId = dict
	}
}
