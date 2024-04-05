//
//  FeedlyUpdateAccountFeedsWithItemsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser
import os.log
import Database

/// Combine the articles with their feeds for a specific account.
final class FeedlyUpdateAccountFeedsWithItemsOperation: FeedlyOperation {

	private let account: Account
	private let organisedItemsProvider: FeedlyParsedItemsByFeedProviding
	private let log: OSLog

	init(account: Account, organisedItemsProvider: FeedlyParsedItemsByFeedProviding, log: OSLog) {

		self.account = account
		self.organisedItemsProvider = organisedItemsProvider
		self.log = log
	}
	
	override func run() {

		let feedIDsAndItems = organisedItemsProvider.parsedItemsKeyedByFeedId
		
		Task { @MainActor in
			do {

				try await account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
				os_log(.debug, log: self.log, "Updated %i feeds for \"%@\"", feedIDsAndItems.count, self.organisedItemsProvider.parsedItemsByFeedProviderName)
				self.didFinish()
				
			} catch {
				self.didFinish(with: error)
			}
		}
	}
}
