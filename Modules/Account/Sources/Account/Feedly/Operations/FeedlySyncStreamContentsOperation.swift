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
		Feedly.logger.info("Feedly: Canceling sync stream contents for \(self.resource.id)")
		operationQueue.cancelAllOperations()
		super.didCancel()
	}

	func enqueueOperations(for continuation: String?) {
		Feedly.logger.info("Feedly: Requesting page for \(self.resource.id)")
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
			Feedly.logger.info("Feedly: Canceled requesting page for \(self.resource.id)")
			return
		}

		Feedly.logger.info("Feedly: Ingesting \(stream.items.count) items from \(stream.id)")

		guard isPagingEnabled, let continuation = stream.continuation else {
			Feedly.logger.info("Feedly: Reached end of stream for \(stream.id)")
			return
		}

		enqueueOperations(for: continuation)
	}

	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		Feedly.logger.info("Feedly: Finished ingesting items from \(self.resource.id)")
		didFinish()
	}

	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		operationQueue.cancelAllOperations()
		didFinish(with: error)
	}
}
