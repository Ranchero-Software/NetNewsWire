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
		
		account.fetchUnreadArticleIDs(didFetchUnreadArticleIDs(_:))
	}
	
	private func didFetchUnreadArticleIDs(_ localUnreadArticleIds: Set<String>) {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		let group = DispatchGroup()
		let remoteUnreadArticleIds = allUnreadIdsProvider.entryIds
		
		// Mark articles as unread
		let deltaUnreadArticleIds = remoteUnreadArticleIds.subtracting(localUnreadArticleIds)
		let markUnreadArticles = account.fetchArticles(.articleIDs(deltaUnreadArticleIds))
		account.update(markUnreadArticles, statusKey: .read, flag: false)

		// Save any unread statuses for articles we haven't yet received
		let markUnreadArticleIDs = Set(markUnreadArticles.map { $0.articleID })
		let missingUnreadArticleIDs = deltaUnreadArticleIds.subtracting(markUnreadArticleIDs)

		group.enter()
		account.ensureStatuses(missingUnreadArticleIDs, true, .read, false) {
			group.leave()
		}

		// Mark articles as read
		let deltaReadArticleIds = localUnreadArticleIds.subtracting(remoteUnreadArticleIds)
		let markReadArticles = account.fetchArticles(.articleIDs(deltaReadArticleIds))
		account.update(markReadArticles, statusKey: .read, flag: true)

		// Save any read statuses for articles we haven't yet received
		let markReadArticleIDs = Set(markReadArticles.map { $0.articleID })
		let missingReadArticleIDs = deltaReadArticleIds.subtracting(markReadArticleIDs)
		group.enter()
		account.ensureStatuses(missingReadArticleIDs, true, .read, true) {
			group.leave()
		}

		group.notify(queue: .main, execute: didFinish)
	}
}
