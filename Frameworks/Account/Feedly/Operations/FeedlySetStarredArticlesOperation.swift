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

		account.fetchStarredArticleIDs { result in
			switch result {
			case .success(let localStarredArticleIDs):
				self.processStarredArticleIDs(localStarredArticleIDs)
				
			case .failure(let error):
				self.didFinish(error)
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
		
		let remoteStarredArticleIDs = allStarredEntryIdsProvider.entryIds
		guard !remoteStarredArticleIDs.isEmpty else {
			didFinish()
			return
		}
		
		let group = DispatchGroup()
		
		final class StarredStatusResults {
			var markAsStarredError: Error?
			var markAsUnstarredError: Error?
		}
		
		let results = StarredStatusResults()
		
		group.enter()
		account.markAsStarred(remoteStarredArticleIDs) { error in
			results.markAsStarredError = error
			group.leave()
		}

		let deltaUnstarredArticleIDs = localStarredArticleIDs.subtracting(remoteStarredArticleIDs)
		group.enter()
		account.markAsUnstarred(deltaUnstarredArticleIDs) { error in
			results.markAsUnstarredError = error
			group.leave()
		}

		group.notify(queue: .main) {
			let markingError = results.markAsStarredError ?? results.markAsUnstarredError
			guard let error = markingError else {
				self.didFinish()
				return
			}
			self.didFinish(error)
		}
	}
}
