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
	private let missingArticleEntryIDProvider: FeedlyEntryIdentifierProviding
	private let updatedArticleEntryIDProvider: FeedlyEntryIdentifierProviding
	private let getEntriesService: FeedlyGetEntriesService
	private let operationQueue = MainThreadOperationQueue()
	private let finishOperation: FeedlyCheckpointOperation
	
	init(account: Account, missingArticleEntryIDProvider: FeedlyEntryIdentifierProviding, updatedArticleEntryIDProvider: FeedlyEntryIdentifierProviding, getEntriesService: FeedlyGetEntriesService) {
		self.account = account
		self.operationQueue.suspend()
		self.missingArticleEntryIDProvider = missingArticleEntryIDProvider
		self.updatedArticleEntryIDProvider = updatedArticleEntryIDProvider
		self.getEntriesService = getEntriesService
		self.finishOperation = FeedlyCheckpointOperation()
		super.init()
		self.finishOperation.checkpointDelegate = self
		self.operationQueue.add(self.finishOperation)
	}
	
	override func run() {
		var articleIDs = missingArticleEntryIDProvider.entryIDs
		articleIDs.formUnion(updatedArticleEntryIDProvider.entryIDs)
		
        self.logger.debug("Requesting \(articleIDs.count, privacy: .public) articles.")
		
		let feedlyAPILimitBatchSize = 1000
		for articleIDs in Array(articleIDs).chunked(into: feedlyAPILimitBatchSize) {
			
			let provider = FeedlyEntryIdentifierProvider(entryIDs: Set(articleIDs))
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
        logger.debug("Cancelling \(String(describing: self), privacy: .public).")
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
        self.logger.debug("\(String(describing: operation), privacy: .public) failed with error: \(error.localizedDescription, privacy: .public)")
		
		cancel()
	}
}
