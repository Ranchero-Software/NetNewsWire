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

class FeedlyAddNewFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlySearchOperationDelegate, FeedlyCheckpointOperationDelegate {
	private let operationQueue: OperationQueue
	private let folder: Folder
	private let collectionId: String
	private let url: String
	private let account: Account
	private let credentials: Credentials
	private let feedName: String?
	private let addToCollectionService: FeedlyAddFeedToCollectionService
	private let syncUnreadIdsService: FeedlyGetStreamIdsService
	private let getStreamContentsService: FeedlyGetStreamContentsService
	private let log: OSLog
	
	var addCompletionHandler: ((Result<WebFeed, Error>) -> ())?
	
	init(account: Account, credentials: Credentials, url: String, feedName: String?, searchService: FeedlySearchService, addToCollectionService: FeedlyAddFeedToCollectionService, syncUnreadIdsService: FeedlyGetStreamIdsService, getStreamContentsService: FeedlyGetStreamContentsService, container: Container, progress: DownloadProgress, log: OSLog) throws {
		
		let validator = FeedlyFeedContainerValidator(container: container, userId: credentials.username)
		(self.folder, self.collectionId) = try validator.getValidContainer()
		
		self.url = url
		self.operationQueue = OperationQueue()
		self.operationQueue.isSuspended = true
		self.account = account
		self.credentials = credentials
		self.feedName = feedName
		self.addToCollectionService = addToCollectionService
		self.syncUnreadIdsService = syncUnreadIdsService
		self.getStreamContentsService = getStreamContentsService
		self.log = log
		
		super.init()
		
		self.downloadProgress = progress
		
		let search = FeedlySearchOperation(query: url, locale: .current, service: searchService)
		search.delegate = self
		search.searchDelegate = self
		search.downloadProgress = progress
		self.operationQueue.addOperation(search)
	}
	
	override func cancel() {
		operationQueue.cancelAllOperations()
		super.cancel()
		
		didFinish()
		
		// Operation should silently cancel.
		addCompletionHandler = nil
	}
	
	override func main() {
		guard !isCancelled else {
			return
		}
		operationQueue.isSuspended = false
	}
	
	private var feedResourceId: FeedlyFeedResourceId?
	
	func feedlySearchOperation(_ operation: FeedlySearchOperation, didGet response: FeedlyFeedsSearchResponse) {
		guard !isCancelled else {
			return
		}
		guard let first = response.results.first else {
			return didFinish(AccountError.createErrorNotFound)
		}
		
		let feedResourceId = FeedlyFeedResourceId(id: first.feedId)
		self.feedResourceId = feedResourceId
		
		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: feedResourceId, feedName: feedName, collectionId: collectionId, service: addToCollectionService)
		addRequest.delegate = self
		addRequest.downloadProgress = downloadProgress
		self.operationQueue.addOperation(addRequest)
		
		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest, log: log)
		createFeeds.addDependency(addRequest)
		createFeeds.downloadProgress = downloadProgress
		self.operationQueue.addOperation(createFeeds)
		
		let syncUnread = FeedlySyncUnreadStatusesOperation(account: account, credentials: credentials, service: syncUnreadIdsService, newerThan: nil, log: log)
		syncUnread.addDependency(createFeeds)
		syncUnread.downloadProgress = downloadProgress
		self.operationQueue.addOperation(syncUnread)
		
		let syncFeed = FeedlySyncStreamContentsOperation(account: account, resource: feedResourceId, service: getStreamContentsService, newerThan: nil, log: log)
		syncFeed.addDependency(syncUnread)
		syncFeed.downloadProgress = downloadProgress
		self.operationQueue.addOperation(syncFeed)
		
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = downloadProgress
		finishOperation.addDependency(syncFeed)
		self.operationQueue.addOperation(finishOperation)
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
		
		if let feedResource = feedResourceId, let feed = folder.existingWebFeed(withWebFeedID: feedResource.id) {
			handler(.success(feed))
			
		} else {
			handler(.failure(AccountError.createErrorNotFound))
		}
		
		addCompletionHandler = nil
	}
}
