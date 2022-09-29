//
//  FeedlyDownloadArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb

class FeedlyDownloadArticlesOperation: FeedlyOperation, Logging {

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
		
        self.logger.debug("Requesting \(articleIds.count) articles.")
		
		let feedlyAPILimitBatchSize = 1000
		for articleIds in Array(articleIds).chunked(into: feedlyAPILimitBatchSize) {
			
			let provider = FeedlyEntryIdentifierProvider(entryIds: Set(articleIds))
			let getEntries = FeedlyGetEntriesOperation(account: account, service: getEntriesService, provider: provider)
			getEntries.delegate = self
			self.operationQueue.add(getEntries)
			
			let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account,
																		  parsedItemProvider: getEntries)
			organiseByFeed.delegate = self
			organiseByFeed.addDependency(getEntries)
			self.operationQueue.add(organiseByFeed)
			
			let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
			organisedItemsProvider: organiseByFeed)
			
			updateAccount.delegate = self
			updateAccount.addDependency(organiseByFeed)
			self.operationQueue.add(updateAccount)

			finishOperation.addDependency(updateAccount)
		}
		
		operationQueue.resume()
	}

	override func didCancel() {
        logger.debug("Cancelling \(String(describing: self)).")
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
        self.logger.debug("\(String(describing: operation)) failed with error: \(error.localizedDescription, privacy: .public)")
		
		cancel()
	}
}
