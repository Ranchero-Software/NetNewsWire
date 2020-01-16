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

class FeedlyDownloadArticlesOperation: FeedlyOperation {
	private let account: Account
	private let log: OSLog
	private let missingArticleEntryIdProvider: FeedlyEntryIdentifierProviding
	private let updatedArticleEntryIdProvider: FeedlyEntryIdentifierProviding
	private let getEntriesService: FeedlyGetEntriesService
	private let operationQueue = MainThreadOperationQueue()
	private let finishOperation: FeedlyCheckpointOperation
	
	init(account: Account, missingArticleEntryIdProvider: FeedlyEntryIdentifierProviding, updatedArticleEntryIdProvider: FeedlyEntryIdentifierProviding, getEntriesService: FeedlyGetEntriesService, log: OSLog) {
		self.account = account
		self.operationQueue.suspend()
		self.missingArticleEntryIdProvider = missingArticleEntryIdProvider
		self.updatedArticleEntryIdProvider = updatedArticleEntryIdProvider
		self.getEntriesService = getEntriesService
		self.finishOperation = FeedlyCheckpointOperation()
		self.log = log
		
		super.init()
		
		self.finishOperation.checkpointDelegate = self
		self.operationQueue.addOperation(self.finishOperation)
	}
	
	override func cancel() {
		// TODO: fix error on below line: "Expression type '()' is ambiguous without more context"
		//os_log(.debug, log: log, "Cancelling %{public}@.", self)
		operationQueue.cancelAllOperations()
		super.cancel()
		didFinish()
	}
	
	override func run() {
		super.run()

		var articleIds = missingArticleEntryIdProvider.entryIds
		articleIds.formUnion(updatedArticleEntryIdProvider.entryIds)
		
		os_log(.debug, log: log, "Requesting %{public}i articles.", articleIds.count)
		
		let feedlyAPILimitBatchSize = 1000
		for articleIds in Array(articleIds).chunked(into: feedlyAPILimitBatchSize) {
			
			let provider = FeedlyEntryIdentifierProvider(entryIds: Set(articleIds))
			let getEntries = FeedlyGetEntriesOperation(account: account, service: getEntriesService, provider: provider, log: log)
			getEntries.delegate = self
			self.operationQueue.addOperation(getEntries)
			
			let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account,
																		  parsedItemProvider: getEntries,
																		  log: log)
			organiseByFeed.delegate = self
			self.operationQueue.make(organiseByFeed, dependOn: getEntries)
			self.operationQueue.addOperation(organiseByFeed)
			
			let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
			organisedItemsProvider: organiseByFeed,
			log: log)
			
			updateAccount.delegate = self
			self.operationQueue.make(updateAccount, dependOn: organiseByFeed)
			self.operationQueue.addOperation(updateAccount)

			self.operationQueue.make(finishOperation, dependOn: updateAccount)
		}
		
		operationQueue.resume()
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
		// TODO: fix error for below line "Error is not convertible to NSError"
		//os_log(.debug, log: log, "%{public}@ failed with error: %{public}@.", operation, error as NSError)
		cancel()
	}
}
