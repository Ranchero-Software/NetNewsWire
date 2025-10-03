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

/// Combine the articles with their feeds for a specific account.
final class FeedlyUpdateAccountFeedsWithItemsOperation: FeedlyOperation {

	private let account: Account
	private let organisedItemsProvider: FeedlyParsedItemsByFeedProviding

	init(account: Account, organisedItemsProvider: FeedlyParsedItemsByFeedProviding) {
		self.account = account
		self.organisedItemsProvider = organisedItemsProvider
	}
	
	override func run() {
		let webFeedIDsAndItems = organisedItemsProvider.parsedItemsKeyedByFeedId
		
		account.update(webFeedIDsAndItems: webFeedIDsAndItems, defaultRead: true) { databaseError in
			if let error = databaseError {
				self.didFinish(with: error)
				return
			}

			Feedly.logger.info("Feedly: updated \(webFeedIDsAndItems.count) for \(self.organisedItemsProvider.parsedItemsByFeedProviderName)")
			self.didFinish()
		}
	}
}
