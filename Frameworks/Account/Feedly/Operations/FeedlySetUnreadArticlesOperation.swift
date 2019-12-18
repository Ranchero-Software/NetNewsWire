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
		guard !remoteUnreadArticleIDs.isEmpty else {
			didFinish()
			return
		}
		
		let group = DispatchGroup()
		
		final class ReadStatusResults {
			var markAsUnreadError: Error?
			var markAsReadError: Error?
		}
		
		let results = ReadStatusResults()
		
		group.enter()
		account.markAsUnread(remoteUnreadArticleIDs) { error in
			results.markAsUnreadError = error
			group.leave()
		}

		let articleIDsToMarkRead = localUnreadArticleIDs.subtracting(remoteUnreadArticleIDs)
		group.enter()
		account.markAsRead(articleIDsToMarkRead) { error in
			results.markAsReadError = error
			group.leave()
		}

		group.notify(queue: .main) {
			let markingError = results.markAsReadError ?? results.markAsUnreadError
			guard let error = markingError else {
				self.didFinish()
				return
			}
			self.didFinish(error)
		}
	}
}
