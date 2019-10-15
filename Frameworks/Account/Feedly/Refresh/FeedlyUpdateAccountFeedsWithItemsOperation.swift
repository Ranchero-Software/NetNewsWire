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
		assert(Thread.isMainThread) // Needs to be on main thread because Feed is a main-thread-only model type.
		guard !isCancelled else {
			didFinish()
			return
		}
		
		let allFeeds = organisedItemsProvider.allFeeds
		
		os_log(.debug, log: log, "Begin updating %i feeds for \"%@\"", allFeeds.count, organisedItemsProvider.providerName)

		var feedIDsAndItems = [String: Set<ParsedItem>]()
		for feed in allFeeds {
			guard let items = organisedItemsProvider.parsedItems(for: feed) else {
				continue
			}
			feedIDsAndItems[feed.feedID] = items
		}
		account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true) {
			os_log(.debug, log: self.log, "Finished updating feeds for \"%@\"", self.organisedItemsProvider.providerName)
			self.didFinish()
		}
	}
}
