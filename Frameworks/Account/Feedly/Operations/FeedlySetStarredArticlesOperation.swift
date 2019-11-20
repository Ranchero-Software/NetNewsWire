//
//  FeedlySetStarredArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 14/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyStarredEntryIdProviding {
	var entryIds: Set<String> { get }
}

/// Single responsibility is to associate a starred status for ingested and remote
/// articles identfied by the provided identifiers *for the entire account.*
final class FeedlySetStarredArticlesOperation: FeedlyOperation {
	private let account: Account
	private let allStarredEntryIdsProvider: FeedlyStarredEntryIdProviding
	private let log: OSLog
	
	init(account: Account, allStarredEntryIdsProvider: FeedlyStarredEntryIdProviding, log: OSLog) {
		self.account = account
		self.allStarredEntryIdsProvider = allStarredEntryIdsProvider
		self.log = log
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		let group = DispatchGroup()
		
		let remoteStarredArticleIds = allStarredEntryIdsProvider.entryIds
		let localStarredArticleIDs = account.fetchStarredArticleIDs()
		
		// Mark articles as starred
		let deltaStarredArticleIDs = remoteStarredArticleIds.subtracting(localStarredArticleIDs)
		let markStarredArticles = account.fetchArticles(.articleIDs(deltaStarredArticleIDs))
		account.update(markStarredArticles, statusKey: .starred, flag: true)

		// Save any starred statuses for articles we haven't yet received
		let markStarredArticleIDs = Set(markStarredArticles.map { $0.articleID })
		let missingStarredArticleIDs = deltaStarredArticleIDs.subtracting(markStarredArticleIDs)
		group.enter()
		account.ensureStatuses(missingStarredArticleIDs, true, .starred, true) {
			group.leave()
		}

		// Mark articles as unstarred
		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIds)
		let markUnstarredArticles = account.fetchArticles(.articleIDs(deltaUnstarredArticleIDs))
		account.update(markUnstarredArticles, statusKey: .starred, flag: false)

		// Save any unstarred statuses for articles we haven't yet received
		let markUnstarredArticleIDs = Set(markUnstarredArticles.map { $0.articleID })
		let missingUnstarredArticleIDs = deltaUnstarredArticleIDs.subtracting(markUnstarredArticleIDs)
		group.enter()
		account.ensureStatuses(missingUnstarredArticleIDs, true, .starred, false) {
			group.leave()
		}
		
		group.notify(queue: .main) {
			self.didFinish()
		}
	}
}
