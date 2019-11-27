//
//  FeedlySyncUnreadStatusesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser

/// Makes one or more requests to get the complete set of unread article ids to update the status of those articles *for the entire account.*
final class FeedlySyncUnreadStatusesOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyGetStreamIdsOperationDelegate, FeedlyCheckpointOperationDelegate {
	private let account: Account
	private let resource: FeedlyResourceId
	private let operationQueue: OperationQueue
	private let service: FeedlyGetStreamIdsService
	private let log: OSLog
	
	/// Buffers every unread article id from every page of the resource's stream.
	private class UnreadEntryIdsProvider: FeedlyUnreadEntryIdProviding {
		let resource: FeedlyResourceId
		private(set) var entryIds = Set<String>()
		
		init(resource: FeedlyResourceId) {
			self.resource = resource
		}
		
		func addEntryIds(from provider: FeedlyEntryIdenifierProviding) {
			entryIds.formUnion(provider.entryIds)
		}
	}
	
	private let unreadEntryIdsProvider: UnreadEntryIdsProvider
	private let setStatuses: FeedlySetUnreadArticlesOperation
	
	convenience init(account: Account, credentials: Credentials, service: FeedlyGetStreamIdsService, newerThan: Date?, log: OSLog) {
		let resource = FeedlyCategoryResourceId.Global.all(for: credentials.username)
		self.init(account: account, resource: resource, service: service, newerThan: newerThan, log: log)
	}
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamIdsService, newerThan: Date?, log: OSLog) {
		self.account = account
		self.resource = resource
		self.service = service
		self.operationQueue = OperationQueue()
		self.operationQueue.isSuspended = true
		self.log = log
				
		let provider = UnreadEntryIdsProvider(resource: resource)
		self.unreadEntryIdsProvider = provider
		self.setStatuses = FeedlySetUnreadArticlesOperation(account: account,
															allUnreadIdsProvider: unreadEntryIdsProvider,
															log: log)

		super.init()
		
		let getFirstPageOfUnreadIds = FeedlyGetStreamIdsOperation(account: account,
																  resource: resource,
																  service: service,
																  newerThan: nil,
																  unreadOnly: true,
																  log: log)
		
		getFirstPageOfUnreadIds.delegate = self
		getFirstPageOfUnreadIds.streamIdsDelegate = self
		
		setStatuses.addDependency(getFirstPageOfUnreadIds)
		setStatuses.delegate = self
		
		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.addDependency(setStatuses)
		
		let operations = [getFirstPageOfUnreadIds, setStatuses, finishOperation]
		operationQueue.addOperations(operations, waitUntilFinished: false)
	}
	
	override func cancel() {
		os_log(.debug, log: log, "Canceling sync unread statuses")
		operationQueue.cancelAllOperations()
		super.cancel()
		didFinish()
	}
	
	override func main() {
		guard !isCancelled else {
			// override of cancel calls didFinish().
			return
		}
		
		operationQueue.isSuspended = false
	}
	
	func feedlyGetStreamIdsOperation(_ operation: FeedlyGetStreamIdsOperation, didGet streamIds: FeedlyStreamIds) {
		guard !isCancelled else {
			os_log(.debug, log: log, "Cancelled unread stream ids.")
			return
		}
		
		os_log(.debug, log: log, "Collecting %i unread article ids from %@", streamIds.ids.count, resource.id)
		unreadEntryIdsProvider.addEntryIds(from: operation)
		
		guard let continuation = streamIds.continuation else {
			return
		}
		
		let nextPageOperation = FeedlyGetStreamIdsOperation(account: operation.account,
															resource: operation.resource,
															service: operation.service,
															continuation: continuation,
															newerThan: operation.newerThan,
															unreadOnly: operation.unreadOnly,
															log: log)
		nextPageOperation.delegate = self
		nextPageOperation.streamIdsDelegate = self
		
		setStatuses.addDependency(nextPageOperation)
		operationQueue.addOperation(nextPageOperation)
	}
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		didFinish()
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		operationQueue.cancelAllOperations()
		didFinish(error)
	}
}
