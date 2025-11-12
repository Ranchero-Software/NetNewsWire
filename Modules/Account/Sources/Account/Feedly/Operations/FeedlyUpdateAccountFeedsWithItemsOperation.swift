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
final class FeedlyUpdateAccountFeedsWithItemsOperation: FeedlyOperation, @unchecked Sendable {

	private let account: Account
	private let organisedItemsProvider: FeedlyParsedItemsByFeedProviding

	@MainActor init(account: Account, organisedItemsProvider: FeedlyParsedItemsByFeedProviding) {
		self.account = account
		self.organisedItemsProvider = organisedItemsProvider
		super.init()
	}

	override func run() {
		Task { @MainActor in
			let feedIDsAndItems = organisedItemsProvider.parsedItemsKeyedByFeedId
			do {
				try await account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true)
				didComplete()
			} catch {
				didComplete(with: error)
			}
		}
	}
}
