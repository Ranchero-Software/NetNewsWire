//
//  FeedlySyncStreamContentsOperation.swift
//  Account
//
//  Created by Kiel Gillard on 17/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSCore
import RSWeb
import Secrets

final class FeedlySyncStreamContentsOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyGetStreamContentsOperationDelegate, FeedlyCheckpointOperationDelegate, Logging {

	private let account: Account
	private let resource: FeedlyResourceId
	private let operationQueue = MainThreadOperationQueue()
	private let service: FeedlyGetStreamContentsService
	private let newerThan: Date?
	private let isPagingEnabled: Bool
	private let finishOperation: FeedlyCheckpointOperation
	
	init(account: Account, resource: FeedlyResourceId, service: FeedlyGetStreamContentsService, isPagingEnabled: Bool, newerThan: Date?) {
		self.account = account
		self.resource = resource
		self.service = service
		self.isPagingEnabled = isPagingEnabled
		self.operationQueue.suspend()
		self.newerThan = newerThan
		self.finishOperation = FeedlyCheckpointOperation()
		
		super.init()
		
		self.operationQueue.add(self.finishOperation)
		self.finishOperation.checkpointDelegate = self
		enqueueOperations(for: nil)
	}
	
	convenience init(account: Account, credentials: Credentials, service: FeedlyGetStreamContentsService, newerThan: Date?) {
		let all = FeedlyCategoryResourceId.Global.all(for: credentials.username)
		self.init(account: account, resource: all, service: service, isPagingEnabled: true, newerThan: newerThan)
	}
	
	override func run() {
		operationQueue.resume()
	}

	override func didCancel() {
        self.logger.debug("Cancelling sync stream contents for \(self.resource.id).")
		operationQueue.cancelAllOperations()
		super.didCancel()
	}

	func enqueueOperations(for continuation: String?) {
        self.logger.debug("Requesting page for \(self.resource.id).")
		let operations = pageOperations(for: continuation)
		operationQueue.addOperations(operations)
	}
	
	func pageOperations(for continuation: String?) -> [MainThreadOperation] {
		let getPage = FeedlyGetStreamContentsOperation(account: account,
													   resource: resource,
													   service: service,
													   continuation: continuation,
													   newerThan: newerThan)

		
		let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account, parsedItemProvider: getPage)
		
		let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: organiseByFeed)
		
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
            self.logger.debug("Cancelled requesting page for \(self.resource.id).")
			return
		}
		
        self.logger.debug("Ingesting \(stream.items.count) from \(stream.id).")
		
		guard isPagingEnabled, let continuation = stream.continuation else {
            self.logger.debug("Reached end of stream for \(stream.id).")
			return
		}
		
		enqueueOperations(for: continuation)
	}
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
        self.logger.debug("Completed ingesting items from \(self.resource.id).")
		didFinish()
	}
	
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		operationQueue.cancelAllOperations()
		didFinish(with: error)
	}
}
