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

/// Single responsibility is to compose the operations necessary to get the entire set of articles, feeds and folders with the statuses the user expects between now and a certain date in the past.
final class FeedlySyncAllOperation: FeedlyOperation {
	private let operationQueue: OperationQueue
	private let log: OSLog
	let syncUUID: UUID
	
	var syncCompletionHandler: ((Result<Void, Error>) -> ())?
	
	init(account: Account, credentials: Credentials, lastSuccessfulFetchStartDate: Date?, markArticlesService: FeedlyMarkArticlesService, getUnreadService: FeedlyGetStreamIdsService, getCollectionsService: FeedlyGetCollectionsService, getStreamContentsService: FeedlyGetStreamContentsService, getStarredArticlesService: FeedlyGetStreamContentsService, database: SyncDatabase, downloadProgress: DownloadProgress, log: OSLog) {
		self.syncUUID = UUID()
		self.log = log
		self.operationQueue = OperationQueue()
		self.operationQueue.isSuspended = true
		
		super.init()
		
		self.downloadProgress = downloadProgress
		
		// Send any read/unread/starred article statuses to Feedly before anything else.
		let sendArticleStatuses = FeedlySendArticleStatusesOperation(database: database, service: markArticlesService, log: log)
		sendArticleStatuses.delegate = self
		sendArticleStatuses.downloadProgress = downloadProgress
		self.operationQueue.addOperation(sendArticleStatuses)
		
		// Get all the Collections the user has.
		let getCollections = FeedlyGetCollectionsOperation(service: getCollectionsService, log: log)
		getCollections.delegate = self
		getCollections.downloadProgress = downloadProgress
		getCollections.addDependency(sendArticleStatuses)
		self.operationQueue.addOperation(getCollections)
		
		// Ensure a folder exists for each Collection, removing Folders without a corresponding Collection.
		let mirrorCollectionsAsFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: getCollections, log: log)
		mirrorCollectionsAsFolders.delegate = self
		mirrorCollectionsAsFolders.addDependency(getCollections)
		self.operationQueue.addOperation(mirrorCollectionsAsFolders)
		
		// Ensure feeds are created and grouped by their folders.
		let createFeedsOperation = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: mirrorCollectionsAsFolders, log: log)
		createFeedsOperation.delegate = self
		createFeedsOperation.addDependency(mirrorCollectionsAsFolders)
		self.operationQueue.addOperation(createFeedsOperation)
		
		// Get each page of unread article ids in the global.all stream for the last 31 days (nil = Feedly API default).
		let getUnread = FeedlySyncUnreadStatusesOperation(account: account, credentials: credentials, service: getUnreadService, newerThan: nil, log: log)
		getUnread.delegate = self
		getUnread.addDependency(createFeedsOperation)
		getUnread.downloadProgress = downloadProgress
		self.operationQueue.addOperation(getUnread)
		
		// Get each page of the global.all stream until we get either the content from the last sync or the last 31 days.
		let getStreamContents = FeedlySyncStreamContentsOperation(account: account, credentials: credentials, service: getStreamContentsService, newerThan: lastSuccessfulFetchStartDate, log: log)
		getStreamContents.delegate = self
		getStreamContents.downloadProgress = downloadProgress
		getStreamContents.addDependency(getUnread)
		self.operationQueue.addOperation(getStreamContents)
		
		// Get each and every starred article.
		let syncStarred = FeedlySyncStarredArticlesOperation(account: account, credentials: credentials, service: getStarredArticlesService, log: log)
		syncStarred.downloadProgress = downloadProgress
		syncStarred.addDependency(createFeedsOperation)
		self.operationQueue.addOperation(syncStarred)
		
		// Once this operation's dependencies, their dependencies etc finish, we can finish.
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.downloadProgress = downloadProgress
		finishOperation.addDependency(getStreamContents)
		finishOperation.addDependency(syncStarred)

		self.operationQueue.addOperation(finishOperation)
	}
	
	convenience init(account: Account, credentials: Credentials, caller: FeedlyAPICaller, database: SyncDatabase, lastSuccessfulFetchStartDate: Date?, downloadProgress: DownloadProgress, log: OSLog) {
		
		let newerThan: Date? = {
			if let date = lastSuccessfulFetchStartDate {
				return date
			} else {
				return Calendar.current.date(byAdding: .day, value: -31, to: Date())
			}
		}()
		
		self.init(account: account, credentials: credentials, lastSuccessfulFetchStartDate: newerThan, markArticlesService: caller, getUnreadService: caller, getCollectionsService: caller, getStreamContentsService: caller, getStarredArticlesService: caller, database: database, downloadProgress: downloadProgress, log: log)
	}
	
	override func cancel() {
		os_log(.debug, log: log, "Cancelling sync %{public}@", syncUUID.uuidString)
		self.operationQueue.cancelAllOperations()
		
		super.cancel()
		
		didFinish()
		
		// Operation should silently cancel.
		syncCompletionHandler = nil
	}
	
	override func main() {
		guard !isCancelled else {
			// override of cancel calls didFinish().
			return
		}
		
		os_log(.debug, log: log, "Starting sync %{public}@", syncUUID.uuidString)
		operationQueue.isSuspended = false
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
		os_log(.debug, log: log, "%{public}@ failed with error: %{public}@.", operation, error as NSError)
		
		syncCompletionHandler?(.failure(error))
		syncCompletionHandler = nil
		
		cancel()
	}
}
