//
//  FeedlySyncStrategy.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

final class FeedlySyncStrategy {
	
	let account: Account
	let caller: FeedlyAPICaller
	let operationQueue: OperationQueue
	let log: OSLog
	
	init(account: Account, caller: FeedlyAPICaller, log: OSLog) {
		self.account = account
		self.caller = caller
		self.operationQueue = OperationQueue()
		self.log = log
	}
	
	func cancel() {
		os_log(.debug, log: log, "Cancelling all operations.")
		self.operationQueue.cancelAllOperations()
	}
	
	private var startSyncCompletionHandler: ((Result<Void, Error>) -> ())?
	
	/// The truth is in the cloud.
	func startSync(completionHandler: @escaping (Result<Void, Error>) -> ()) {
		guard operationQueue.operationCount == 0 else {
			os_log(.debug, log: log, "Reqeusted start sync but ignored because a sync is already in progress.")
			return
		}
		
		// Since the truth is in the cloud, everything hinges of what Collections the user has.
		let getCollections = FeedlyGetCollectionsOperation(caller: caller)
		getCollections.delegate = self
		
		// Ensure a folder exists for each Collection, removing Folders without a corresponding Collection.
		let mirrorCollectionsAsFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account,
																				   collectionsProvider: getCollections,
																				   caller: caller)
		mirrorCollectionsAsFolders.delegate = self
		mirrorCollectionsAsFolders.addDependency(getCollections)
		
		// Ensure feeds are created and grouped by their folders.
		let createFeedsOperation = FeedlyCreateFeedsForCollectionFoldersOperation(account: account,
																				  collectionsAndFoldersProvider: mirrorCollectionsAsFolders,
																				  log: log)
		createFeedsOperation.delegate = self
		createFeedsOperation.addDependency(mirrorCollectionsAsFolders)

		
		// Get the streams for each Collection. It will call back to enqueue more operations.
		let getCollectionStreams = FeedlyRequestStreamsOperation(account: account,
																 collectionsProvider: getCollections,
																 caller: caller,
																 log: log)
		getCollectionStreams.delegate = self
		getCollectionStreams.queueDelegate = self
		getCollectionStreams.addDependency(getCollections)
		
		// Last operation to perform, which should be dependent on any other operation added to the queue.
		let syncId = UUID().uuidString
		let completionOperation = BlockOperation { [weak self] in
			if let self = self {
				os_log(.debug, log: self.log, "Sync completed: %@", syncId)
				self.startSyncCompletionHandler = nil
			}
			completionHandler(.success(()))
		}
		
		completionOperation.addDependency(getCollections)
		completionOperation.addDependency(mirrorCollectionsAsFolders)
		completionOperation.addDependency(createFeedsOperation)
		completionOperation.addDependency(getCollectionStreams)
		
		finalOperation = completionOperation
		startSyncCompletionHandler = completionHandler
		
		let minimumOperations = [getCollections,
								 mirrorCollectionsAsFolders,
								 createFeedsOperation,
								 getCollectionStreams,
								 completionOperation]
		
		operationQueue.addOperations(minimumOperations, waitUntilFinished: false)
		
		os_log(.debug, log: log, "Sync started: %@", syncId)
	}
	
	private var finalOperation: Operation?
}

extension FeedlySyncStrategy: FeedlyRequestStreamsOperationDelegate {
	
	func feedlyRequestStreamsOperation(_ operation: FeedlyRequestStreamsOperation, enqueue collectionStreamOperation: FeedlyGetCollectionStreamOperation) {
		
		collectionStreamOperation.delegate = self
				
		os_log(.debug, log: log, "Requesting stream for collection \"%@\"", collectionStreamOperation.collection.label)
		
		// Parse the contents of this collection's stream.
		let parseItemsOperation = FeedlyGetStreamParsedItemsOperation(account: account,
																	  collectionStreamProvider: collectionStreamOperation,
																	  caller: caller,
																	  log: log)
		parseItemsOperation.delegate = self
		parseItemsOperation.addDependency(collectionStreamOperation)
		
		// Group the stream's content by feed.
		let groupItemsByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account,
																		parsedItemsProvider: parseItemsOperation,
																		log: log)
		groupItemsByFeed.delegate = self
		groupItemsByFeed.addDependency(parseItemsOperation)
		
		// Update the account with the articles for the feeds in the stream.
		let updateOperation = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
																		 organisedItemsProvider: groupItemsByFeed,
																		 log: log)
		updateOperation.delegate = self
		updateOperation.addDependency(groupItemsByFeed)
		
		// Sync completes successfully when the account has been updated with all the parsedd entries from the stream.
		if let operation = finalOperation {
			operation.addDependency(updateOperation)
		}
		
		let operations = [collectionStreamOperation, parseItemsOperation, groupItemsByFeed, updateOperation]
		
		operationQueue.addOperations(operations, waitUntilFinished: false)
	}
}

extension FeedlySyncStrategy: FeedlySyncOperationDelegate {
	
	func feedlySyncOperation(_ operation: FeedlySyncOperation, didFailWith error: Error) {
		os_log(.debug, log: log, "**** Operation failed! **** %@", error as NSError)
		cancel()
		
		startSyncCompletionHandler?(.failure(error))
		startSyncCompletionHandler = nil
	}
}
