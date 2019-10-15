//
//  FeedlySetStarredArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 14/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

/// Single responsibility is to update or ensure articles from the entry provider are the only starred articles.
final class FeedlySetStarredArticlesOperation: FeedlyOperation {
	private let account: Account
	private let allStarredEntriesProvider: FeedlyEntryProviding
	private let log: OSLog
	
	init(account: Account, allStarredEntriesProvider: FeedlyEntryProviding, log: OSLog) {
		self.account = account
		self.allStarredEntriesProvider = allStarredEntriesProvider
		self.log = log
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else {
			return
		}
		
		let remoteStarredArticleIds = Set(allStarredEntriesProvider.entries.map { $0.id })
		let localStarredArticleIDs = account.fetchStarredArticleIDs()
		
		// Mark articles as starred
		let deltaStarredArticleIDs = remoteStarredArticleIds.subtracting(localStarredArticleIDs)
		let markStarredArticles = account.fetchArticles(.articleIDs(deltaStarredArticleIDs))
		account.update(markStarredArticles, statusKey: .starred, flag: true)

		// Save any starred statuses for articles we haven't yet received
		let markStarredArticleIDs = Set(markStarredArticles.map { $0.articleID })
		let missingStarredArticleIDs = deltaStarredArticleIDs.subtracting(markStarredArticleIDs)
		account.ensureStatuses(missingStarredArticleIDs, true, .starred, true)

		// Mark articles as unstarred
		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIds)
		let markUnstarredArticles = account.fetchArticles(.articleIDs(deltaUnstarredArticleIDs))
		account.update(markUnstarredArticles, statusKey: .starred, flag: false)

		// Save any unstarred statuses for articles we haven't yet received
		let markUnstarredArticleIDs = Set(markUnstarredArticles.map { $0.articleID })
		let missingUnstarredArticleIDs = deltaUnstarredArticleIDs.subtracting(markUnstarredArticleIDs)
		account.ensureStatuses(missingUnstarredArticleIDs, true, .starred, false)
	}
}
