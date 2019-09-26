//
//  FeedlyUpdateAccountFeedsWithItemsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import os.log

/// Single responsibility is to combine the articles with their feeds for a specific account.
final class FeedlyUpdateAccountFeedsWithItemsOperation: FeedlyOperation {
	private let account: Account
	private let organisedItemsProvider: FeedlyParsedItemsByFeedProviding
	private let log: OSLog
	
	init(account: Account, organisedItemsProvider: FeedlyParsedItemsByFeedProviding, log: OSLog) {
		self.account = account
		self.organisedItemsProvider = organisedItemsProvider
		self.log = log
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		let group = DispatchGroup()
		let allFeeds = organisedItemsProvider.allFeeds
		
		os_log(.debug, log: log, "Begin updating %i feeds in collection \"%@\"", allFeeds.count, organisedItemsProvider.collection.label)
		
		for feed in allFeeds {
			guard let items = organisedItemsProvider.parsedItems(for: feed) else {
				continue
			}
			group.enter()
			os_log(.debug, log: log, "Updating %i items for feed \"%@\" in collection \"%@\"", items.count, feed.nameForDisplay, organisedItemsProvider.collection.label)
			
			account.update(feed, parsedItems: items, defaultRead: true) {
				group.leave()
			}
		}
		
		group.notify(qos: .userInitiated, queue: .main) {
			os_log(.debug, log: self.log, "Finished updating feeds in collection \"%@\"", self.organisedItemsProvider.collection.label)
			self.didFinish()
		}
	}
}
