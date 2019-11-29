//
//  FeedlyAddNewFeedOperation.swift
//  Account
//
//  Created by Kiel Gillard on 27/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb

class FeedlyAddNewFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyCheckpointOperationDelegate {
	private let operationQueue: OperationQueue
	private let folder: Folder
	private let feedResourceId: FeedlyFeedResourceId
	
	var addCompletionHandler: ((Result<WebFeed, Error>) -> ())?
	
	init(account: Account, credentials: Credentials, resource: FeedlyFeedResourceId, feedName: String?, caller: FeedlyAPICaller, container: Container, progress: DownloadProgress, log: OSLog) throws {
		
		let validator = FeedlyFeedContainerValidator(container: container, userId: credentials.username)
		let (folder, collectionId) = try validator.getValidContainer()
		
		self.folder = folder
		self.feedResourceId = resource
		self.operationQueue = OperationQueue()
		self.operationQueue.isSuspended = true
		
		super.init()
		
		self.downloadProgress = progress
		
		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: resource, feedName: feedName, collectionId: collectionId, caller: caller)
		addRequest.delegate = self
		addRequest.downloadProgress = progress
		self.operationQueue.addOperation(addRequest)
		
		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest, log: log)
		createFeeds.addDependency(addRequest)
		createFeeds.downloadProgress = progress
		self.operationQueue.addOperation(createFeeds)
		
		let syncUnread = FeedlySyncUnreadStatusesOperation(account: account, credentials: credentials, service: caller, newerThan: nil, log: log)
		syncUnread.addDependency(addRequest)
		syncUnread.downloadProgress = progress
		self.operationQueue.addOperation(syncUnread)
		
		let syncFeed = FeedlySyncStreamContentsOperation(account: account, resource: resource, service: caller, newerThan: nil, log: log)
		syncFeed.addDependency(syncUnread)
		syncFeed.downloadProgress = progress
		self.operationQueue.addOperation(syncFeed)
		
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = progress
		finishOperation.addDependency(syncFeed)
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
		
		defer {
			didFinish()
		}
		
		guard let handler = addCompletionHandler else {
			return
		}
		
		if let feed = folder.existingWebFeed(withWebFeedID: feedResourceId.id) {
			handler(.success(feed))
			
		} else {
			handler(.failure(AccountError.createErrorNotFound))
		}
		
		addCompletionHandler = nil
	}
}
