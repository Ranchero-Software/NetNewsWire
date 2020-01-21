//
//  FeedlyAddNewFeedOperation.swift
//  Account
//
//  Created by Kiel Gillard on 27/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import SyncDatabase
import RSWeb
import RSCore

class FeedlyAddNewFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlySearchOperationDelegate, FeedlyCheckpointOperationDelegate {

	private let operationQueue = MainThreadOperationQueue()
	private let folder: Folder
	private let collectionId: String
	private let url: String
	private let account: Account
	private let credentials: Credentials
	private let database: SyncDatabase
	private let feedName: String?
	private let addToCollectionService: FeedlyAddFeedToCollectionService
	private let syncUnreadIdsService: FeedlyGetStreamIdsService
	private let getStreamContentsService: FeedlyGetStreamContentsService
	private let log: OSLog
	private var feedResourceId: FeedlyFeedResourceId?
	var addCompletionHandler: ((Result<WebFeed, Error>) -> ())?

	init(account: Account, credentials: Credentials, url: String, feedName: String?, searchService: FeedlySearchService, addToCollectionService: FeedlyAddFeedToCollectionService, syncUnreadIdsService: FeedlyGetStreamIdsService, getStreamContentsService: FeedlyGetStreamContentsService, database: SyncDatabase, container: Container, progress: DownloadProgress, log: OSLog) throws {
		

		let validator = FeedlyFeedContainerValidator(container: container)
		(self.folder, self.collectionId) = try validator.getValidContainer()
		
		self.url = url
		self.operationQueue.suspend()
		self.account = account
		self.credentials = credentials
		self.database = database
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
	
	override func run() {
		operationQueue.resume()
	}

	override func didCancel() {
		operationQueue.cancelAllOperations()
		addCompletionHandler = nil
		super.didCancel()
	}

	func feedlySearchOperation(_ operation: FeedlySearchOperation, didGet response: FeedlyFeedsSearchResponse) {
		guard !isCanceled else {
			return
		}
		guard let first = response.results.first else {
			return didFinish(with: AccountError.createErrorNotFound)
		}
		
		let feedResourceId = FeedlyFeedResourceId(id: first.feedId)
		self.feedResourceId = feedResourceId
		
		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: feedResourceId, feedName: feedName, collectionId: collectionId, service: addToCollectionService)
		addRequest.delegate = self
		addRequest.downloadProgress = downloadProgress
		operationQueue.addOperation(addRequest)
		
		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest, log: log)
		createFeeds.addDependency(addRequest)
		createFeeds.downloadProgress = downloadProgress
		operationQueue.addOperation(createFeeds)
		
		let syncUnread = FeedlyIngestUnreadArticleIdsOperation(account: account, credentials: credentials, service: syncUnreadIdsService, database: database, newerThan: nil, log: log)
		syncUnread.addDependency(createFeeds)
		syncUnread.downloadProgress = downloadProgress
		operationQueue.addOperation(syncUnread)
		
		let syncFeed = FeedlySyncStreamContentsOperation(account: account, resource: feedResourceId, service: getStreamContentsService, isPagingEnabled: false, newerThan: nil, log: log)
		syncFeed.addDependency(syncUnread)
		syncFeed.downloadProgress = downloadProgress
		operationQueue.addOperation(syncFeed)
		
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = downloadProgress
		finishOperation.addDependency(syncFeed)
		operationQueue.addOperation(finishOperation)
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
		defer {
			didFinish()
		}
		
		guard let handler = addCompletionHandler else {
			return
		}
		if let feedResource = feedResourceId, let feed = folder.existingWebFeed(withWebFeedID: feedResource.id) {
			handler(.success(feed))
		}
		else {
			handler(.failure(AccountError.createErrorNotFound))
		}
		addCompletionHandler = nil
	}
}
