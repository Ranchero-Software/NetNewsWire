//
//  FeedlySyncStrategy.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import SyncDatabase

final class FeedlySyncStrategy {
	
	let account: Account
	let caller: FeedlyAPICaller
	let operationQueue: OperationQueue
	let database: SyncDatabase
	let log: OSLog
	
	init(account: Account, caller: FeedlyAPICaller, database: SyncDatabase, log: OSLog) {
		self.account = account
		self.caller = caller
		self.operationQueue = OperationQueue()
		self.log = log
		self.database = database
	}
	
	func cancel() {
		os_log(.debug, log: log, "Cancelling all operations.")
		self.operationQueue.cancelAllOperations()
	}
	
	private var startSyncCompletionHandler: ((Result<Void, Error>) -> ())?
	
	private var newerThan: Date? {
		if let date = account.metadata.lastArticleFetch {
			return date
		} else {
			return Calendar.current.date(byAdding: .day, value: -31, to: Date())
		}
	}
	
	/// The truth is in the cloud.
	func startSync(completionHandler: @escaping (Result<Void, Error>) -> ()) {
		guard operationQueue.operationCount == 0 else {
			os_log(.debug, log: log, "Reqeusted start sync but ignored because a sync is already in progress.")
			completionHandler(.success(()))
			return
		}
		
		guard let credentials = caller.credentials else {
			completionHandler(.failure(FeedlyAccountDelegateError.notLoggedIn))
			return
		}
		
		let sendArticleStatuses = FeedlySendArticleStatusesOperation(database: database, caller: caller, log: log)
		sendArticleStatuses.delegate = self
		
		
		// Since the truth is in the cloud, everything hinges of what Collections the user has.
		let getCollections = FeedlyGetCollectionsOperation(caller: caller, log: log)
		getCollections.delegate = self
		getCollections.addDependency(sendArticleStatuses)
		
		// Ensure a folder exists for each Collection, removing Folders without a corresponding Collection.
		let mirrorCollectionsAsFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account,
																				   collectionsProvider: getCollections,
																				   caller: caller,
																				   log: log)
		mirrorCollectionsAsFolders.delegate = self
		mirrorCollectionsAsFolders.addDependency(getCollections)
		
		// Ensure feeds are created and grouped by their folders.
		let createFeedsOperation = FeedlyCreateFeedsForCollectionFoldersOperation(account: account,
																				  feedsAndFoldersProvider: mirrorCollectionsAsFolders,
																				  log: log)
		createFeedsOperation.delegate = self
		createFeedsOperation.addDependency(mirrorCollectionsAsFolders)

		
		// Get the streams for each Collection. It will call back to enqueue more operations.
		let getCollectionStreams = FeedlyRequestStreamsOperation(account: account,
																 collectionsProvider: getCollections,
																 newerThan: newerThan,
																 unreadOnly: false,
																 caller: caller,
																 log: log)
		getCollectionStreams.delegate = self
		getCollectionStreams.queueDelegate = self
		getCollectionStreams.addDependency(getCollections)
		
		let syncStarred = FeedlySyncStarredArticlesOperation(account: account, credentials: credentials, caller: caller, log: log)
		syncStarred.addDependency(getCollections)
		syncStarred.addDependency(mirrorCollectionsAsFolders)
		syncStarred.addDependency(createFeedsOperation)
		
		// Last operation to perform, which should be dependent on any other operation added to the queue.
		let syncId = UUID().uuidString
		let lastArticleFetchDate = Date()
		let completionOperation = BlockOperation { [weak self] in
			DispatchQueue.main.async {
				if let self = self {
					self.account.metadata.lastArticleFetch = lastArticleFetchDate
					os_log(.debug, log: self.log, "Sync completed: %@", syncId)
					self.startSyncCompletionHandler = nil
				}
				completionHandler(.success(()))
			}
		}
		
		completionOperation.addDependency(sendArticleStatuses)
		completionOperation.addDependency(getCollections)
		completionOperation.addDependency(mirrorCollectionsAsFolders)
		completionOperation.addDependency(createFeedsOperation)
		completionOperation.addDependency(getCollectionStreams)
		completionOperation.addDependency(syncStarred)
		
		finalOperation = completionOperation
		startSyncCompletionHandler = completionHandler
		
		let minimumOperations = [sendArticleStatuses,
								 getCollections,
								 mirrorCollectionsAsFolders,
								 createFeedsOperation,
								 getCollectionStreams,
								 syncStarred,
								 completionOperation]
		
		operationQueue.addOperations(minimumOperations, waitUntilFinished: false)
		
		os_log(.debug, log: log, "Sync started: %@", syncId)
	}
	
	private weak var finalOperation: Operation?
}

extension FeedlySyncStrategy: FeedlyRequestStreamsOperationDelegate {
	
	func feedlyRequestStreamsOperation(_ operation: FeedlyRequestStreamsOperation, enqueue streamOperation: FeedlyGetStreamOperation) {
		
		streamOperation.delegate = self
				
//		os_log(.debug, log: log, "Requesting stream for collection \"%@\"", streamOperation.collection.label)
		
		// Group the stream's content by feed.
		let groupItemsByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account,
																		entryProvider: streamOperation,
																		log: log)
		groupItemsByFeed.delegate = self
		groupItemsByFeed.addDependency(streamOperation)
		
		// Update the account with the articles for the feeds in the stream.
		let updateOperation = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
																		 organisedItemsProvider: groupItemsByFeed,
																		 log: log)
		updateOperation.delegate = self
		updateOperation.addDependency(groupItemsByFeed)
		
		// Once the articles are in the account, ensure they have the correct status
		let ensureUnreadOperation = FeedlyRefreshStreamEntriesStatusOperation(account: account,
																			  entryProvider: streamOperation,
																			  log: log)
		
		ensureUnreadOperation.delegate = self
		ensureUnreadOperation.addDependency(updateOperation)
		
		// Sync completes successfully when the account has been updated with all the parsedd entries from the stream.
		if let operation = finalOperation {
			operation.addDependency(ensureUnreadOperation)
		}
		
		let operations = [streamOperation, groupItemsByFeed, updateOperation, ensureUnreadOperation]
		
		operationQueue.addOperations(operations, waitUntilFinished: false)
	}
}

extension FeedlySyncStrategy: FeedlyOperationDelegate {
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		os_log(.debug, log: log, "%@ failed so sync failed with error %@", operation, error.localizedDescription)
		cancel()
		
		startSyncCompletionHandler?(.failure(error))
		startSyncCompletionHandler = nil
	}
}
