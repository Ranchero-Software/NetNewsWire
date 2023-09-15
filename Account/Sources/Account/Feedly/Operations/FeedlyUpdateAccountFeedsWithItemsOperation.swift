//
//  FeedlyUpdateAccountFeedsWithItemsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore

/// Combine the articles with their feeds for a specific account.
final class FeedlyUpdateAccountFeedsWithItemsOperation: FeedlyOperation, Logging {

	private let account: Account
	private let organisedItemsProvider: FeedlyParsedItemsByFeedProviding

	init(account: Account, organisedItemsProvider: FeedlyParsedItemsByFeedProviding) {
		self.account = account
		self.organisedItemsProvider = organisedItemsProvider
	}
	
	override func run() {
		let feedIDsAndItems = organisedItemsProvider.parsedItemsKeyedByFeedID
		
		account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true) { databaseError in
			if let error = databaseError {
				self.didFinish(with: error)
				return
			}
			
            self.logger.debug("Updated \(feedIDsAndItems.count, privacy: .public) feeds for \(self.organisedItemsProvider.parsedItemsByFeedProviderName, privacy: .public).")
			self.didFinish()
		}
	}
}
