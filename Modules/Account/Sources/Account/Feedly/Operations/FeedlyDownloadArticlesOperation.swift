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

final class FeedlyDownloadArticlesOperation: FeedlyOperation {

	private let account: Account
	private let missingArticleEntryIdProvider: FeedlyEntryIdentifierProviding
	private let updatedArticleEntryIdProvider: FeedlyEntryIdentifierProviding
	private let getEntriesService: FeedlyGetEntriesService
	private let operationQueue = MainThreadOperationQueue()
	private let finishOperation: FeedlyCheckpointOperation
	
	init(account: Account, missingArticleEntryIdProvider: FeedlyEntryIdentifierProviding, updatedArticleEntryIdProvider: FeedlyEntryIdentifierProviding, getEntriesService: FeedlyGetEntriesService) {
		self.account = account
		self.operationQueue.suspend()
		self.missingArticleEntryIdProvider = missingArticleEntryIdProvider
		self.updatedArticleEntryIdProvider = updatedArticleEntryIdProvider
		self.getEntriesService = getEntriesService
		self.finishOperation = FeedlyCheckpointOperation()
		super.init()
		self.finishOperation.checkpointDelegate = self
		self.operationQueue.add(self.finishOperation)
	}
	
	override func run() {
		var articleIds = missingArticleEntryIdProvider.entryIds
		articleIds.formUnion(updatedArticleEntryIdProvider.entryIds)

		Feedly.logger.info("Feedly: Requesting \(articleIds.count) articles")

		let feedlyAPILimitBatchSize = 1000
		for articleIds in Array(articleIds).chunked(into: feedlyAPILimitBatchSize) {
			
			let provider = FeedlyEntryIdentifierProvider(entryIds: Set(articleIds))
			let getEntries = FeedlyGetEntriesOperation(account: account, service: getEntriesService, provider: provider)
			getEntries.delegate = self
			self.operationQueue.add(getEntries)
			
			let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(
				account: account,
				parsedItemProvider: getEntries
			)
			organiseByFeed.delegate = self
			organiseByFeed.addDependency(getEntries)
			self.operationQueue.add(organiseByFeed)
			
			let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(
				account: account,
				organisedItemsProvider: organiseByFeed
			)
			
			updateAccount.delegate = self
			updateAccount.addDependency(organiseByFeed)
			self.operationQueue.add(updateAccount)

			finishOperation.addDependency(updateAccount)
		}
		
		operationQueue.resume()
	}

	override func didCancel() {
		// TODO: fix error on below line: "Expression type '()' is ambiguous without more context"
			//os_log(.debug, log: log, "Cancelling %{public}@.", self)
		operationQueue.cancelAllOperations()
		super.didCancel()
	}
}

extension FeedlyDownloadArticlesOperation: FeedlyCheckpointOperationDelegate {
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		didFinish()
	}
}

extension FeedlyDownloadArticlesOperation: FeedlyOperationDelegate {
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		assert(Thread.isMainThread)
		
		// Having this log is useful for debugging missing required JSON keys in the response from Feedly, for example.
		Feedly.logger.error("Feedly: FeedlyDownloadArticlesOperation did fail with error: \(error.localizedDescription)")
		cancel()
	}
}
