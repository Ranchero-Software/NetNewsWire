//
//  FeedlySyncAllOperation.swift
//  Account
//
//  Created by Kiel Gillard on 19/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import SyncDatabase
import RSWeb
import RSCore
import Secrets

/// Compose the operations necessary to get the entire set of articles, feeds and folders with the statuses the user expects between now and a certain date in the past.
final class FeedlySyncAllOperation: FeedlyOperation, @unchecked Sendable {
	let syncUUID: UUID

	var syncCompletionHandler: ((Result<Void, Error>) -> ())?

	/// These requests to Feedly determine which articles to download:
	/// 1. The set of all article ids we might need or show.
	/// 2. The set of all unread article ids we might need or show (a subset of 1).
	/// 3. The set of all article ids changed since the last sync (a subset of 1).
	/// 4. The set of all starred article ids.
	///
	/// On the response for 1, create statuses for each article id.
	/// On the response for 2, create unread statuses for each article id and mark as read those no longer in the response.
	/// On the response for 4, create starred statuses for each article id and mark as unstarred those no longer in the response.
	///
	/// Download articles for statuses at the union of those statuses without its corresponding article and those included in 3 (changed since last successful sync).
	///
	@MainActor init(account: Account, feedlyUserId: String, lastSuccessfulFetchStartDate: Date?, markArticlesService: FeedlyMarkArticlesService, getUnreadService: FeedlyGetStreamIdsService, getCollectionsService: FeedlyGetCollectionsService, getStreamContentsService: FeedlyGetStreamContentsService, getStarredService: FeedlyGetStreamIdsService, getStreamIdsService: FeedlyGetStreamIdsService, getEntriesService: FeedlyGetEntriesService, database: SyncDatabase, operationQueue: MainThreadOperationQueue) {
		self.syncUUID = UUID()

		super.init(name: "FeedlySyncAllOperation")

		operationQueue.suspend()

		// Send any read/unread/starred article statuses to Feedly before anything else.
		let sendArticleStatuses = FeedlySendArticleStatusesOperation(database: database, service: markArticlesService)
		sendArticleStatuses.delegate = self
		operationQueue.add(sendArticleStatuses)

		// Get all the Collections the user has.
		let getCollections = FeedlyGetCollectionsOperation(service: getCollectionsService)
		getCollections.delegate = self
		getCollections.addDependency(sendArticleStatuses)
		operationQueue.add(getCollections)

		// Ensure a folder exists for each Collection, removing Folders without a corresponding Collection.
		let mirrorCollectionsAsFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: getCollections)
		mirrorCollectionsAsFolders.delegate = self
		mirrorCollectionsAsFolders.addDependency(getCollections)
		operationQueue.add(mirrorCollectionsAsFolders)

		// Ensure feeds are created and grouped by their folders.
		let createFeedsOperation = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: mirrorCollectionsAsFolders)
		createFeedsOperation.delegate = self
		createFeedsOperation.addDependency(mirrorCollectionsAsFolders)
		operationQueue.add(createFeedsOperation)

		let getAllArticleIds = FeedlyIngestStreamArticleIdsOperation(account: account, userId: feedlyUserId, service: getStreamIdsService)
		getAllArticleIds.delegate = self
		getAllArticleIds.addDependency(createFeedsOperation)
		operationQueue.add(getAllArticleIds)

		// Get each page of unread article ids in the global.all stream for the last 31 days (nil = Feedly API default).
		let getUnread = FeedlyIngestUnreadArticleIdsOperation(account: account, userId: feedlyUserId, service: getUnreadService, database: database, newerThan: nil)
		getUnread.delegate = self
		getUnread.addDependency(getAllArticleIds)
		operationQueue.add(getUnread)

		// Get each page of the article ids which have been update since the last successful fetch start date.
		// If the date is nil, this operation provides an empty set (everything is new, nothing is updated).
		let getUpdated = FeedlyGetUpdatedArticleIdsOperation(account: account, userId: feedlyUserId, service: getStreamIdsService, newerThan: lastSuccessfulFetchStartDate)
		getUpdated.delegate = self
		getUpdated.addDependency(createFeedsOperation)
		operationQueue.add(getUpdated)

		// Get each page of the article ids for starred articles.
		let getStarred = FeedlyIngestStarredArticleIdsOperation(account: account, userId: feedlyUserId, service: getStarredService, database: database, newerThan: nil)
		getStarred.delegate = self
		getStarred.addDependency(createFeedsOperation)
		operationQueue.add(getStarred)

		// Now all the possible article ids we need have a status, fetch the article ids for missing articles.
		let getMissingIDs = FeedlyFetchIDsForMissingArticlesOperation(account: account)
		getMissingIDs.delegate = self
		getMissingIDs.addDependency(getAllArticleIds)
		getMissingIDs.addDependency(getUnread)
		getMissingIDs.addDependency(getStarred)
		getMissingIDs.addDependency(getUpdated)
		operationQueue.add(getMissingIDs)

		// Download all the missing and updated articles
		let downloadMissingArticles = FeedlyDownloadArticlesOperation(
			account: account,
			missingArticleEntryIdProvider: getMissingIDs,
			updatedArticleEntryIdProvider: getUpdated,
			getEntriesService: getEntriesService,
			operationQueue: operationQueue
		)
		downloadMissingArticles.delegate = self
		downloadMissingArticles.addDependency(getMissingIDs)
		downloadMissingArticles.addDependency(getUpdated)
		operationQueue.add(downloadMissingArticles)

		// Once this operation's dependencies, their dependencies etc finish, we can finish.
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.addDependency(downloadMissingArticles)
		operationQueue.add(finishOperation)
	}

	@MainActor convenience init(account: Account, feedlyUserId: String, caller: FeedlyAPICaller, database: SyncDatabase, lastSuccessfulFetchStartDate: Date?, operationQueue: MainThreadOperationQueue) {
		self.init(account: account, feedlyUserId: feedlyUserId, lastSuccessfulFetchStartDate: lastSuccessfulFetchStartDate, markArticlesService: caller, getUnreadService: caller, getCollectionsService: caller, getStreamContentsService: caller, getStarredService: caller, getStreamIdsService: caller, getEntriesService: caller, database: database, operationQueue: operationQueue)
	}

	@MainActor override func run() {
		Feedly.logger.info("Feedly: Starting sync \(self.syncUUID.uuidString, privacy: .public)")
		didComplete()
	}

	@MainActor override func noteDidComplete() {
		if isCanceled {
			Feedly.logger.info("Feedly: Canceling sync \(self.syncUUID.uuidString, privacy: .public)")
			operationQueue?.cancelAll()
			syncCompletionHandler = nil
		}
		super.noteDidComplete()
	}
}

extension FeedlySyncAllOperation: FeedlyCheckpointOperationDelegate {

	@MainActor func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		assert(Thread.isMainThread)
		Feedly.logger.info("Feedly: Sync finished \(self.syncUUID.uuidString, privacy: .public)")

		syncCompletionHandler?(.success(()))
		syncCompletionHandler = nil

		didComplete()
	}
}

extension FeedlySyncAllOperation: FeedlyOperationDelegate {

	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		assert(Thread.isMainThread)

		MainActor.assumeIsolated {
			// Having this log is useful for debugging missing required JSON keys in the response from Feedly, for example.
			Feedly.logger.error("Feedly: Sync \(self.syncUUID.uuidString, privacy: .public) failed with error: \(error.localizedDescription)")
			
			syncCompletionHandler?(.failure(error))
			syncCompletionHandler = nil
			
			cancel()
		}
	}
}
