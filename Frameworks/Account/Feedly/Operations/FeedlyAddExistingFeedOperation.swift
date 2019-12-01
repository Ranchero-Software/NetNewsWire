//
//  FeedlyAddExistingFeedOperation.swift
//  Account
//
//  Created by Kiel Gillard on 27/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb

class FeedlyAddExistingFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyCheckpointOperationDelegate {
	private let operationQueue: OperationQueue
	
	var addCompletionHandler: ((Result<Void, Error>) -> ())?
	
	init(account: Account, credentials: Credentials, resource: FeedlyFeedResourceId, service: FeedlyAddFeedToCollectionService, container: Container, progress: DownloadProgress, log: OSLog) throws {
		
		let validator = FeedlyFeedContainerValidator(container: container, userId: credentials.username)
		let (folder, collectionId) = try validator.getValidContainer()
		
		self.operationQueue = OperationQueue()
		self.operationQueue.isSuspended = true
		
		super.init()
		
		self.downloadProgress = progress
		
		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: resource, feedName: nil, collectionId: collectionId, service: service)
		addRequest.delegate = self
		addRequest.downloadProgress = progress
		self.operationQueue.addOperation(addRequest)
		
		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest, log: log)
		createFeeds.downloadProgress = progress
		createFeeds.addDependency(addRequest)
		self.operationQueue.addOperation(createFeeds)
		
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = progress
		finishOperation.addDependency(createFeeds)
		self.operationQueue.addOperation(finishOperation)
	}
	
	override func cancel() {
		operationQueue.cancelAllOperations()
		super.cancel()
		didFinish()
	}
	
	override func main() {
		guard !isCancelled else {
			return
		}
		operationQueue.isSuspended = false
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		addCompletionHandler?(.failure(error))
		addCompletionHandler = nil
		
		cancel()
	}
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		guard !isCancelled else {
			return
		}
		
		addCompletionHandler?(.success(()))
		addCompletionHandler = nil
		
		didFinish()
	}
}
