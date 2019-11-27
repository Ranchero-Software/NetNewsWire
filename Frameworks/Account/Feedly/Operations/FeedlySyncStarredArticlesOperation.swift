//
//  FeedlySyncStarredArticlesOperation.swift
//  Account
//
//  Created by Kiel Gillard on 15/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser

final class FeedlySyncStarredArticlesOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyGetStreamContentsOperationDelegate, FeedlyCheckpointOperationDelegate {
	private let account: Account
	private let operationQueue: OperationQueue
	private let service: FeedlyGetStreamContentsService
	private let log: OSLog
	
	private let setStatuses: FeedlySetStarredArticlesOperation
	private let finishOperation: FeedlyCheckpointOperation
	
	/// Buffers every starred/saved entry from every page.
	private class StarredEntryProvider: FeedlyEntryProviding, FeedlyStarredEntryIdProviding, FeedlyParsedItemProviding {
		var resource: FeedlyResourceId
		
		private(set) var parsedEntries = Set<ParsedItem>()
		private(set) var entries = [FeedlyEntry]()
		
		init(resource: FeedlyResourceId) {
			self.resource = resource
		}
		
		func addEntries(from provider: FeedlyEntryProviding & FeedlyParsedItemProviding) {
			entries.append(contentsOf: provider.entries)
			parsedEntries.formUnion(provider.parsedEntries)
		}
		
		var entryIds: Set<String> {
			return Set(entries.map { $0.id })
		}
	}
	
	private let entryProvider: StarredEntryProvider
	
	convenience init(account: Account, credentials: Credentials, service: FeedlyGetStreamContentsService, log: OSLog) {
		let saved = FeedlyTagResourceId.Global.saved(for: credentials.username)
		self.init(account: account, resource: saved, service: service, log: log)
	}
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamContentsService, log: OSLog) {
		self.account = account
		self.service = service
		self.operationQueue = OperationQueue()
		self.operationQueue.isSuspended = true
		self.finishOperation = FeedlyCheckpointOperation()
		self.log = log
				
		let provider = StarredEntryProvider(resource: resource)
		self.entryProvider = provider
		self.setStatuses = FeedlySetStarredArticlesOperation(account: account,
															 allStarredEntryIdsProvider: provider,
															 log: log)
		
		super.init()
		
		let getFirstPage = FeedlyGetStreamContentsOperation(account: account,
													resource: resource,
													service: service,
													newerThan: nil,
													log: log)
		
		let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account,
																	  parsedItemProvider: provider,
																	  log: log)

		let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account,
																	   organisedItemsProvider: organiseByFeed,
																	   log: log)
		
		getFirstPage.delegate = self
		getFirstPage.streamDelegate = self
		
		setStatuses.addDependency(getFirstPage)
		setStatuses.delegate = self
		
		organiseByFeed.addDependency(setStatuses)
		organiseByFeed.delegate = self
		
		updateAccount.addDependency(organiseByFeed)
		updateAccount.delegate = self
		
		finishOperation.checkpointDelegate = self
		finishOperation.addDependency(updateAccount)
		
		let operations = [getFirstPage, setStatuses, organiseByFeed, updateAccount, finishOperation]
		operationQueue.addOperations(operations, waitUntilFinished: false)
	}
	
	override func cancel() {
		os_log(.debug, log: log, "Canceling sync starred articles")
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
	
	func feedlyGetStreamContentsOperation(_ operation: FeedlyGetStreamContentsOperation, didGetContentsOf stream: FeedlyStream) {
		guard !isCancelled else {
			os_log(.debug, log: log, "Cancelled starred stream contents for %@", stream.id)
			return
		}
		
		entryProvider.addEntries(from: operation)
		os_log(.debug, log: log, "Collecting %i items from %@", stream.items.count, stream.id)
		
		guard let continuation = stream.continuation else {
			return
		}
		
		let nextPageOperation = FeedlyGetStreamContentsOperation(account: operation.account,
														 resource: operation.resource,
														 service: operation.service,
														 continuation: continuation,
														 newerThan: operation.newerThan,
														 log: log)
		nextPageOperation.delegate = self
		nextPageOperation.streamDelegate = self
		
		setStatuses.addDependency(nextPageOperation)
		operationQueue.addOperation(nextPageOperation)
	}
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		didFinish()
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		os_log(.debug, log: log, "%{public}@ failing and cancelling other operations because %{public}@.", operation, error.localizedDescription)
		operationQueue.cancelAllOperations()
		didFinish(error)
	}
}
