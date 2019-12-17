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

		account.fetchUnreadArticleIDs { result in
			switch result {
			case .success(let localUnreadArticleIDs):
				self.processUnreadArticleIDs(localUnreadArticleIDs)
				
			case .failure(let error):
				self.didFinish(error)
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
		account.markAsUnread(remoteUnreadArticleIDs)

		let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
		account.markAsRead(articleIDsToMarkRead)

		didFinish()
	}
}
