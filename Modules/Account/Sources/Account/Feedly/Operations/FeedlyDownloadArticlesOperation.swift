//
//  FeedlyDownloadArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSWeb

final class FeedlyDownloadArticlesOperation: FeedlyOperation, @unchecked Sendable {
	private let account: Account
	private let missingArticleEntryIdProvider: FeedlyEntryIdentifierProviding
	private let updatedArticleEntryIdProvider: FeedlyEntryIdentifierProviding
	private let getEntriesService: FeedlyGetEntriesService
	private let finishOperation: FeedlyCheckpointOperation

	@MainActor init(account: Account, missingArticleEntryIdProvider: FeedlyEntryIdentifierProviding, updatedArticleEntryIdProvider: FeedlyEntryIdentifierProviding, getEntriesService: FeedlyGetEntriesService, operationQueue: MainThreadOperationQueue) {
		self.account = account
		self.missingArticleEntryIdProvider = missingArticleEntryIdProvider
		self.updatedArticleEntryIdProvider = updatedArticleEntryIdProvider
		self.getEntriesService = getEntriesService
		self.finishOperation = FeedlyCheckpointOperation()
		super.init()
		self.finishOperation.checkpointDelegate = self

		operationQueue.suspend()
		operationQueue.add(self.finishOperation)
		operationQueue.resume()
	}

	@MainActor override func run() {
		var articleIds = missingArticleEntryIdProvider.entryIDs
		articleIds.formUnion(updatedArticleEntryIdProvider.entryIDs)

		Feedly.logger.debug("FeedlyDownloadArticlesOperation: Requesting \(articleIds.count) articles")

		let feedlyAPILimitBatchSize = 1000
		for articleIds in Array(articleIds).chunked(into: feedlyAPILimitBatchSize) {

			let provider = FeedlyEntryIdentifierProvider(entryIDs: Set(articleIds))
			let getEntries = FeedlyGetEntriesOperation(account: account, service: getEntriesService, provider: provider)
			getEntries.delegate = self
			self.operationQueue?.add(getEntries)

			let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(
				account: account,
				parsedItemProvider: getEntries
			)
			organiseByFeed.delegate = self
			organiseByFeed.addDependency(getEntries)
			self.operationQueue?.add(organiseByFeed)

			let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(
				account: account,
				organisedItemsProvider: organiseByFeed
			)

			updateAccount.delegate = self
			updateAccount.addDependency(organiseByFeed)
			self.operationQueue?.add(updateAccount)

			finishOperation.addDependency(updateAccount)
		}

		didComplete()
	}

	@MainActor override func noteDidComplete() {
		if isCanceled {
			operationQueue?.cancelAll()
		}
	}
}

extension FeedlyDownloadArticlesOperation: FeedlyCheckpointOperationDelegate {

	@MainActor func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		didComplete()
	}
}

extension FeedlyDownloadArticlesOperation: FeedlyOperationDelegate {

	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		assert(Thread.isMainThread)

		// Having this log is useful for debugging missing required JSON keys in the response from Feedly, for example.
		Feedly.logger.error("Feedly: FeedlyDownloadArticlesOperation did fail with error: \(error.localizedDescription)")
	}
}
