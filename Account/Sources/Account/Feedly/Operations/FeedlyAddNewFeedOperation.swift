//
//  FeedlyAddNewFeedOperation.swift
//  Account
//
//  Created by Kiel Gillard on 27/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import SyncDatabase
import RSWeb
import RSCore
import Secrets
import AccountError

class FeedlyAddNewFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlySearchOperationDelegate, FeedlyCheckpointOperationDelegate, Logging {

	private let operationQueue = MainThreadOperationQueue()
	private let folder: Folder
	private let collectionID: String
	private let url: String
	private let account: Account
	private let credentials: Credentials
	private let database: SyncDatabase
	private let feedName: String?
	private let addToCollectionService: FeedlyAddFeedToCollectionService
	private let syncUnreadIDsService: FeedlyGetStreamIDsService
	private let getStreamContentsService: FeedlyGetStreamContentsService
	private var feedResourceID: FeedlyFeedResourceID?
	var addCompletionHandler: ((Result<Feed, Error>) -> ())?

	init(account: Account, credentials: Credentials, url: String, feedName: String?, searchService: FeedlySearchService, addToCollectionService: FeedlyAddFeedToCollectionService, syncUnreadIDsService: FeedlyGetStreamIDsService, getStreamContentsService: FeedlyGetStreamContentsService, database: SyncDatabase, container: Container, progress: DownloadProgress) throws {
		

		let validator = FeedlyFeedContainerValidator(container: container)
		(self.folder, self.collectionID) = try validator.getValidContainer()
		
		self.url = url
		self.operationQueue.suspend()
		self.account = account
		self.credentials = credentials
		self.database = database
		self.feedName = feedName
		self.addToCollectionService = addToCollectionService
		self.syncUnreadIDsService = syncUnreadIDsService
		self.getStreamContentsService = getStreamContentsService

		super.init()

		self.downloadProgress = progress
		
		let search = FeedlySearchOperation(query: url, locale: .current, service: searchService)
		search.delegate = self
		search.searchDelegate = self
		search.downloadProgress = progress
		self.operationQueue.add(search)
	}
	
	override func run() {
		operationQueue.resume()
	}

	override func didCancel() {
		operationQueue.cancelAllOperations()
		addCompletionHandler = nil
		super.didCancel()
	}
	
	override func didFinish(with error: Error) {
		assert(Thread.isMainThread)
		addCompletionHandler?(.failure(error))
		addCompletionHandler = nil
		super.didFinish(with: error)
	}

	func feedlySearchOperation(_ operation: FeedlySearchOperation, didGet response: FeedlyFeedsSearchResponse) {
		guard !isCanceled else {
			return
		}
		guard let first = response.results.first else {
			return didFinish(with: AccountError.createErrorNotFound)
		}
		
		let feedResourceID = FeedlyFeedResourceID(id: first.feedID)
		self.feedResourceID = feedResourceID
		
		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: feedResourceID, feedName: feedName, collectionID: collectionID, service: addToCollectionService)
		addRequest.delegate = self
		addRequest.downloadProgress = downloadProgress
		operationQueue.add(addRequest)
		
		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest)
		createFeeds.delegate = self
		createFeeds.addDependency(addRequest)
		createFeeds.downloadProgress = downloadProgress
		operationQueue.add(createFeeds)
		
		let syncUnread = FeedlyIngestUnreadArticleIDsOperation(account: account, userID: credentials.username, service: syncUnreadIDsService, database: database, newerThan: nil)
		syncUnread.addDependency(createFeeds)
		syncUnread.downloadProgress = downloadProgress
		syncUnread.delegate = self
		operationQueue.add(syncUnread)
		
		let syncFeed = FeedlySyncStreamContentsOperation(account: account, resource: feedResourceID, service: getStreamContentsService, isPagingEnabled: false, newerThan: nil)
		syncFeed.addDependency(syncUnread)
		syncFeed.downloadProgress = downloadProgress
		syncFeed.delegate = self
		operationQueue.add(syncFeed)
		
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = downloadProgress
		finishOperation.addDependency(syncFeed)
		finishOperation.delegate = self
		operationQueue.add(finishOperation)
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		addCompletionHandler?(.failure(error))
		addCompletionHandler = nil
		
        logger.debug("Unale to add new feed: \(error.localizedDescription, privacy: .public)")
		
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
		if let feedResource = feedResourceID, let feed = folder.existingFeed(withFeedID: feedResource.id) {
			handler(.success(feed))
		}
		else {
			handler(.failure(AccountError.createErrorNotFound))
		}
		addCompletionHandler = nil
	}
}
