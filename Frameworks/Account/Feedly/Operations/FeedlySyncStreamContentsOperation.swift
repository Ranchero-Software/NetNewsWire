//
//  FeedlySyncStreamContentsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 17/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser
import RSCore
import RSWeb
import Secrets

final class FeedlySyncStreamContentsOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyGetStreamContentsOperationDelegate, FeedlyCheckpointOperationDelegate {

	private let account: Account
	private let resource: FeedlyResourceId
	private let operationQueue = MainThreadOperationQueue()
	private let service: FeedlyGetStreamContentsService
	private let newerThan: Date?
	private let isPagingEnabled: Bool
	private let log: OSLog
	private let finishOperation: FeedlyCheckpointOperation
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamContentsService, isPagingEnabled: Bool, newerThan: Date?, log: OSLog) {
		self.account = account
		self.resource = resource
		self.service = service
		self.isPagingEnabled = isPagingEnabled
		self.operationQueue.suspend()
		self.newerThan = newerThan
		self.log = log
		self.finishOperation = FeedlyCheckpointOperation()
		
		super.init()
		
		self.operationQueue.add(self.finishOperation)
		self.finishOperation.checkpointDelegate = self
		enqueueOperations(for: nil)
	}
	
	convenience init(account: Account, credentials: Credentials, service: FeedlyGetStreamContentsService, newerThan: Date?, log: OSLog) {
		let all = FeedlyCategoryResourceId.Global.all(for: credentials.username)
		self.init(account: account, resource: all, service: service, isPagingEnabled: true, newerThan: newerThan, log: log)
	}
	
	override func run() {
		operationQueue.resume()
	}

	override func didCancel() {
		os_log(.debug, log: log, "Canceling sync stream contents")
		operationQueue.cancelAllOperations()
		super.didCancel()
	}

	func enqueueOperations(for continuation: String?) {
		os_log(.debug, log: log, "Requesting page for %@", resource.id)
		let operations = pageOperations(for: continuation)
		operationQueue.addOperations(operations)
	}
	
	func pageOperations(for continuation: String?) -> [MainThreadOperation] {
		let getPage = FeedlyGetStreamContentsOperation(account: account,
													   resource: resource,
													   service: service,
													   continuation: continuation,
													   newerThan: newerThan,
													   log: log)

		
		let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account, parsedItemProvider: getPage, log: log)
		
		let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: organiseByFeed, log: log)
		
		getPage.delegate = self
		getPage.streamDelegate = self

		organiseByFeed.addDependency(getPage)
		organiseByFeed.delegate = self

		updateAccount.addDependency(organiseByFeed)
		updateAccount.delegate = self

		finishOperation.addDependency(updateAccount)

		return [getPage, organiseByFeed, updateAccount]
	}
	
	func feedlyGetStreamContentsOperation(_ operation: FeedlyGetStreamContentsOperation, didGetContentsOf stream: FeedlyStream) {
		guard !isCanceled else {
			os_log(.debug, log: log, "Cancelled requesting page for %@", resource.id)
			return
		}
		
		os_log(.debug, log: log, "Ingesting %i items from %@", stream.items.count, stream.id)
		
		guard isPagingEnabled, let continuation = stream.continuation else {
			os_log(.debug, log: log, "Reached end of stream for %@", stream.id)
			return
		}
		
		enqueueOperations(for: continuation)
	}
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		os_log(.debug, log: log, "Completed ingesting items from %@", resource.id)
		didFinish()
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		operationQueue.cancelAllOperations()
		didFinish(with: error)
	}
}
