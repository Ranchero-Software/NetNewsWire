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

/// Compose the operations necessary to get the entire set of articles, feeds and folders with the statuses the user expects between now and a certain date in the past.
final class FeedlySyncAllOperation: FeedlyOperation {

	private let operationQueue = MainThreadOperationQueue()
	private let log: OSLog
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
	init(account: Account, credentials: Credentials, lastSuccessfulFetchStartDate: Date?, markArticlesService: FeedlyMarkArticlesService, getUnreadService: FeedlyGetStreamIdsService, getCollectionsService: FeedlyGetCollectionsService, getStreamContentsService: FeedlyGetStreamContentsService, getStarredService: FeedlyGetStreamIdsService, getStreamIdsService: FeedlyGetStreamIdsService, getEntriesService: FeedlyGetEntriesService, database: SyncDatabase, downloadProgress: DownloadProgress, log: OSLog) {
		self.syncUUID = UUID()
		self.log = log
		self.operationQueue.suspend()
		
		super.init()
		
		self.downloadProgress = downloadProgress
		
		// Send any read/unread/starred article statuses to Feedly before anything else.
		let sendArticleStatuses = FeedlySendArticleStatusesOperation(database: database, service: markArticlesService, log: log)
		sendArticleStatuses.delegate = self
		sendArticleStatuses.downloadProgress = downloadProgress
		self.operationQueue.add(sendArticleStatuses)
		
		// Get all the Collections the user has.
		let getCollections = FeedlyGetCollectionsOperation(service: getCollectionsService, log: log)
		getCollections.delegate = self
		getCollections.downloadProgress = downloadProgress
		getCollections.addDependency(sendArticleStatuses)
			self.operationQueue.add(getCollections)
		
		// Ensure a folder exists for each Collection, removing Folders without a corresponding Collection.
		let mirrorCollectionsAsFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: getCollections, log: log)
		mirrorCollectionsAsFolders.delegate = self
		mirrorCollectionsAsFolders.addDependency(getCollections)
		self.operationQueue.add(mirrorCollectionsAsFolders)
		
		// Ensure feeds are created and grouped by their folders.
		let createFeedsOperation = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: mirrorCollectionsAsFolders, log: log)
		createFeedsOperation.delegate = self
		createFeedsOperation.addDependency(mirrorCollectionsAsFolders)
		self.operationQueue.add(createFeedsOperation)
		
		let getAllArticleIds = FeedlyIngestStreamArticleIdsOperation(account: account, credentials: credentials, service: getStreamIdsService, log: log)
		getAllArticleIds.delegate = self
		getAllArticleIds.downloadProgress = downloadProgress
		getAllArticleIds.addDependency(createFeedsOperation)
		self.operationQueue.add(getAllArticleIds)
		
		// Get each page of unread article ids in the global.all stream for the last 31 days (nil = Feedly API default).
		let getUnread = FeedlyIngestUnreadArticleIdsOperation(account: account, credentials: credentials, service: getUnreadService, database: database, newerThan: nil, log: log)
		getUnread.delegate = self
		getUnread.addDependency(getAllArticleIds)
		getUnread.downloadProgress = downloadProgress
		self.operationQueue.add(getUnread)
		
		// Get each page of the article ids which have been update since the last successful fetch start date.
		// If the date is nil, this operation provides an empty set (everything is new, nothing is updated).
		let getUpdated = FeedlyGetUpdatedArticleIdsOperation(account: account, credentials: credentials, service: getStreamIdsService, newerThan: lastSuccessfulFetchStartDate, log: log)
		getUpdated.delegate = self
		getUpdated.downloadProgress = downloadProgress
		getUpdated.addDependency(createFeedsOperation)
		self.operationQueue.add(getUpdated)
		
		// Get each page of the article ids for starred articles.
		let getStarred = FeedlyIngestStarredArticleIdsOperation(account: account, credentials: credentials, service: getStarredService, database: database, newerThan: nil, log: log)
		getStarred.delegate = self
		getStarred.downloadProgress = downloadProgress
		getStarred.addDependency(createFeedsOperation)
		self.operationQueue.add(getStarred)
		
		// Now all the possible article ids we need have a status, fetch the article ids for missing articles.
		let getMissingIds = FeedlyFetchIdsForMissingArticlesOperation(account: account, log: log)
		getMissingIds.delegate = self
		getMissingIds.downloadProgress = downloadProgress
		getMissingIds.addDependency(getAllArticleIds)
		getMissingIds.addDependency(getUnread)
		getMissingIds.addDependency(getStarred)
		getMissingIds.addDependency(getUpdated)
		self.operationQueue.add(getMissingIds)
		
		// Download all the missing and updated articles
		let downloadMissingArticles = FeedlyDownloadArticlesOperation(account: account,
																	  missingArticleEntryIdProvider: getMissingIds,
																	  updatedArticleEntryIdProvider: getUpdated,
																	  getEntriesService: getEntriesService,
																	  log: log)
		downloadMissingArticles.delegate = self
		downloadMissingArticles.downloadProgress = downloadProgress
		downloadMissingArticles.addDependency(getMissingIds)
		downloadMissingArticles.addDependency(getUpdated)
		self.operationQueue.add(downloadMissingArticles)
		
		// Once this operation's dependencies, their dependencies etc finish, we can finish.
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = downloadProgress
		finishOperation.addDependency(downloadMissingArticles)
		self.operationQueue.add(finishOperation)
	}
	
	convenience init(account: Account, credentials: Credentials, caller: FeedlyAPICaller, database: SyncDatabase, lastSuccessfulFetchStartDate: Date?, downloadProgress: DownloadProgress, log: OSLog) {
		self.init(account: account, credentials: credentials, lastSuccessfulFetchStartDate: lastSuccessfulFetchStartDate, markArticlesService: caller, getUnreadService: caller, getCollectionsService: caller, getStreamContentsService: caller, getStarredService: caller, getStreamIdsService: caller, getEntriesService: caller, database: database, downloadProgress: downloadProgress, log: log)
	}
	
	override func run() {
		os_log(.debug, log: log, "Starting sync %{public}@", syncUUID.uuidString)
		operationQueue.resume()
	}

	override func didCancel() {
		os_log(.debug, log: log, "Cancelling sync %{public}@", syncUUID.uuidString)
		self.operationQueue.cancelAllOperations()
		syncCompletionHandler = nil
		super.didCancel()
	}
}

extension FeedlySyncAllOperation: FeedlyCheckpointOperationDelegate {
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		assert(Thread.isMainThread)
		os_log(.debug, log: self.log, "Sync completed: %{public}@", syncUUID.uuidString)
		
		syncCompletionHandler?(.success(()))
		syncCompletionHandler = nil
		
		didFinish()
	}
}

extension FeedlySyncAllOperation: FeedlyOperationDelegate {
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		assert(Thread.isMainThread)
		
		// Having this log is useful for debugging missing required JSON keys in the response from Feedly, for example.
		os_log(.debug, log: log, "%{public}@ failed with error: %{public}@.", String(describing: operation), error as NSError)
		
		syncCompletionHandler?(.failure(error))
		syncCompletionHandler = nil
		
		cancel()
	}
}
