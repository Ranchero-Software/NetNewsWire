//
//  FeedlyDownloadArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 9/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Web
import Core
import Feedly

class FeedlyDownloadArticlesOperation: FeedlyOperation {

	private let account: Account
	private let log: OSLog
	private let missingArticleEntryIDProvider: FeedlyEntryIdentifierProviding
	private let updatedArticleEntryIDProvider: FeedlyEntryIdentifierProviding
	private let getEntriesService: FeedlyGetEntriesService
	private let operationQueue = MainThreadOperationQueue()
	private let finishOperation: FeedlyCheckpointOperation
	
	@MainActor init(account: Account, missingArticleEntryIDProvider: FeedlyEntryIdentifierProviding, updatedArticleEntryIDProvider: FeedlyEntryIdentifierProviding, getEntriesService: FeedlyGetEntriesService, log: OSLog) {
		self.account = account
		self.operationQueue.suspend()
		self.missingArticleEntryIDProvider = missingArticleEntryIDProvider
		self.updatedArticleEntryIDProvider = updatedArticleEntryIDProvider
		self.getEntriesService = getEntriesService
		self.finishOperation = FeedlyCheckpointOperation()
		self.log = log
		super.init()
		self.finishOperation.checkpointDelegate = self
		self.operationQueue.add(self.finishOperation)
	}
	
	override func run() {
		var articleIDs = missingArticleEntryIDProvider.entryIDs
		articleIDs.formUnion(updatedArticleEntryIDProvider.entryIDs)

		os_log(.debug, log: log, "Requesting %{public}i articles.", articleIDs.count)
		
		let feedlyAPILimitBatchSize = 1000
		for articleIDs in Array(articleIDs).chunked(into: feedlyAPILimitBatchSize) {
			
			Task { @MainActor in
				let provider = FeedlyEntryIdentifierProvider(entryIDs: Set(articleIDs))
				let getEntries = FeedlyGetEntriesOperation(service: self.getEntriesService, provider: provider, log: self.log)
				getEntries.delegate = self
				self.operationQueue.add(getEntries)

				let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(parsedItemProvider: getEntries,
																			  log: log)
				organiseByFeed.delegate = self
				organiseByFeed.addDependency(getEntries)
				self.operationQueue.add(organiseByFeed)

				let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
				organisedItemsProvider: organiseByFeed,
				log: log)

				updateAccount.delegate = self
				updateAccount.addDependency(organiseByFeed)
				self.operationQueue.add(updateAccount)

				finishOperation.addDependency(updateAccount)
			}
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
		os_log(.debug, log: log, "%{public}@ failed with error: %{public}@.", String(describing: operation), error as NSError)
		
		cancel()
	}
}
