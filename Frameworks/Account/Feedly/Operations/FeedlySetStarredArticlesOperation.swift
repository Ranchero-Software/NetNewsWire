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

		account.fetchStarredArticleIDs { (articleIDsResult) in
			if let localStarredArticleIDs = try? articleIDsResult.get() {
				self.processStarredArticleIDs(localStarredArticleIDs)
			}
			else {
				self.didFinish()
			}
		}
	}
}

private extension FeedlySetStarredArticlesOperation {

	func processStarredArticleIDs(_ localStarredArticleIDs: Set<String>) {
		guard !isCancelled else {
			didFinish()
			return
		}

		// Mark as starred
		let remoteStarredArticleIDs = allStarredEntryIdsProvider.entryIds
		account.mark(articleIDs: remoteStarredArticleIDs, statusKey: .starred, flag: true)

		// Mark as unstarred
		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)
		account.mark(articleIDs: deltaUnstarredArticleIDs, statusKey: .starred, flag: false)

		didFinish()
	}
}
