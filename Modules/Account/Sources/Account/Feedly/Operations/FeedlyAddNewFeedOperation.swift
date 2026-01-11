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
import Secrets

final class FeedlyAddNewFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlySearchOperationDelegate, FeedlyCheckpointOperationDelegate, @unchecked Sendable {
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
	private var feedResourceId: FeedlyFeedResourceId?
	var addCompletionHandler: ((Result<Feed, Error>) -> ())?

	@MainActor init(account: Account, credentials: Credentials, url: String, feedName: String?, searchService: FeedlySearchService, addToCollectionService: FeedlyAddFeedToCollectionService, syncUnreadIdsService: FeedlyGetStreamIdsService, getStreamContentsService: FeedlyGetStreamContentsService, database: SyncDatabase, container: Container, operationQueue: MainThreadOperationQueue) throws {

		let validator = FeedlyFeedContainerValidator(container: container)
		(self.folder, self.collectionId) = try validator.getValidContainer()

		self.url = url
		self.account = account
		self.credentials = credentials
		self.database = database
		self.feedName = feedName
		self.addToCollectionService = addToCollectionService
		self.syncUnreadIdsService = syncUnreadIdsService
		self.getStreamContentsService = getStreamContentsService

		super.init()

		operationQueue.suspend()

		let search = FeedlySearchOperation(query: url, locale: .current, service: searchService)
		search.delegate = self
		search.searchDelegate = self
		operationQueue.add(search)
		operationQueue.resume()
	}

	@MainActor override func run() {
		didComplete()
	}

	@MainActor override func noteDidComplete() {
		assert(Thread.isMainThread)
		if isCanceled {
			operationQueue?.cancelAll()
		} else if let error {
			addCompletionHandler?(.failure(error))
		}

		addCompletionHandler = nil
		super.noteDidComplete()
	}

	@MainActor func feedlySearchOperation(_ operation: FeedlySearchOperation, didGet response: FeedlyFeedsSearchResponse) {
		guard !isCanceled else {
			return
		}
		guard let operationQueue else {
			cancel()
			return
		}
		guard let first = response.results.first else {
			error = AccountError.createErrorNotFound
			didComplete()
			return
		}

		let feedResourceId = FeedlyFeedResourceId(id: first.feedId)
		self.feedResourceId = feedResourceId

		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: feedResourceId, feedName: feedName, collectionId: collectionId, service: addToCollectionService)
		addRequest.delegate = self
		operationQueue.add(addRequest)

		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest)
		createFeeds.delegate = self
		createFeeds.addDependency(addRequest)
		operationQueue.add(createFeeds)

		let syncUnread = FeedlyIngestUnreadArticleIdsOperation(account: account, userId: credentials.username, service: syncUnreadIdsService, database: database, newerThan: nil)
		syncUnread.addDependency(createFeeds)
		syncUnread.delegate = self
		operationQueue.add(syncUnread)

		let syncFeed = FeedlySyncStreamContentsOperation(account: account, resource: feedResourceId, service: getStreamContentsService, isPagingEnabled: false, newerThan: nil, operationQueue: operationQueue)
		syncFeed.addDependency(syncUnread)
		syncFeed.delegate = self
		operationQueue.add(syncFeed)

		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.addDependency(syncFeed)
		finishOperation.delegate = self
		operationQueue.add(finishOperation)
	}

	@MainActor func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		self.error = error
		addCompletionHandler?(.failure(error))
		addCompletionHandler = nil

		Feedly.logger.error("FeedlyAddNewFeedOperation: Unable to add new feed with error \(error.localizedDescription)")

		cancel()
	}

	@MainActor func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		guard !isCanceled else {
			return
		}
		defer {
			didComplete()
		}
		
		guard let handler = addCompletionHandler else {
			return
		}
		if let feedResource = feedResourceId, let feed = folder.existingFeed(withFeedID: feedResource.id) {
			handler(.success(feed))
		}
		else {
			handler(.failure(AccountError.createErrorNotFound))
		}
		addCompletionHandler = nil
	}
}
