//
//  FeedlySetUnreadArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 25/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyUnreadEntryIdProviding {
	var entryIds: Set<String> { get }
}

/// Single responsibility is to associate a read status for ingested and remote articles
/// where the provided article identifers identify the unread articles *for the entire account.*
final class FeedlySetUnreadArticlesOperation: FeedlyOperation {
	private let account: Account
	private let allUnreadIdsProvider: FeedlyUnreadEntryIdProviding
	private let log: OSLog
	
	init(account: Account, allUnreadIdsProvider: FeedlyUnreadEntryIdProviding, log: OSLog) {
		self.account = account
		self.allUnreadIdsProvider = allUnreadIdsProvider
		self.log = log
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}

		account.fetchUnreadArticleIDs { articleIDsResult in
			if let localUnreadArticleIDs = try? articleIDsResult.get() {
				self.processUnreadArticleIDs(localUnreadArticleIDs)
			}
			else {
				self.didFinish()
			}
		}
	}
}

private extension FeedlySetUnreadArticlesOperation {

	private func processUnreadArticleIDs(_ localUnreadArticleIDs: Set<String>) {
		guard !isCancelled else {
			didFinish()
			return
		}

		let remoteUnreadArticleIDs = allUnreadIdsProvider.entryIds

		// Mark articles as unread
		account.mark(articleIDs: remoteUnreadArticleIDs, statusKey: .read, flag: false)

		// Mark articles as read
		let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
		account.mark(articleIDs: articleIDsToMarkRead, statusKey: .read, flag: true)

		didFinish()
	}
}
