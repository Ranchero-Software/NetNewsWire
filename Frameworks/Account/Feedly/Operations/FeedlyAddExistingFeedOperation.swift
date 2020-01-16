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
import RSCore

class FeedlyAddExistingFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyCheckpointOperationDelegate {
	private let operationQueue: MainThreadOperationQueue
	
	var addCompletionHandler: ((Result<Void, Error>) -> ())?
	
	init(account: Account, credentials: Credentials, resource: FeedlyFeedResourceId, service: FeedlyAddFeedToCollectionService, container: Container, progress: DownloadProgress, log: OSLog) throws {
		
		let validator = FeedlyFeedContainerValidator(container: container, userId: credentials.username)
		let (folder, collectionId) = try validator.getValidContainer()
		
		self.operationQueue = MainThreadOperationQueue()
		self.operationQueue.suspend()
		
		super.init()
		
		self.downloadProgress = progress
		
		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: resource, feedName: nil, collectionId: collectionId, service: service)
		addRequest.delegate = self
		addRequest.downloadProgress = progress
		self.operationQueue.addOperation(addRequest)
		
		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest, log: log)
		createFeeds.downloadProgress = progress
		self.operationQueue.make(createFeeds, dependOn: addRequest)
		self.operationQueue.addOperation(createFeeds)
		
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = progress
		self.operationQueue.make(finishOperation, dependOn: createFeeds)
		self.operationQueue.addOperation(finishOperation)
	}
	
	override func cancel() {
		operationQueue.cancelAllOperations()
		super.cancel()
		didFinish()
	}
	
	override func run() {
		super.run()
		operationQueue.resume()
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		addCompletionHandler?(.failure(error))
		addCompletionHandler = nil
		
		cancel()
	}
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		guard !isCanceled else {
			return
		}
		
		addCompletionHandler?(.success(()))
		addCompletionHandler = nil
		
		didFinish()
	}
}
