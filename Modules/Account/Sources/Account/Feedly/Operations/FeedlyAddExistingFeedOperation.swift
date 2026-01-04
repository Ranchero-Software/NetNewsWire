//
//  FeedlyAddExistingFeedOperation.swift
//  Account
//
//  Created by Kiel Gillard on 27/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSWeb
import RSCore
import Secrets

final class FeedlyAddExistingFeedOperation: FeedlyOperation, FeedlyOperationDelegate, FeedlyCheckpointOperationDelegate, @unchecked Sendable {
	var addCompletionHandler: ((Result<Void, Error>) -> ())?

	init(account: Account, credentials: Credentials, resource: FeedlyFeedResourceId, service: FeedlyAddFeedToCollectionService, container: Container, customFeedName: String? = nil, operationQueue: MainThreadOperationQueue) throws {

		let validator = FeedlyFeedContainerValidator(container: container)
		let (folder, collectionId) = try validator.getValidContainer()

		operationQueue.suspend()

		super.init()

		let addRequest = FeedlyAddFeedToCollectionOperation(account: account, folder: folder, feedResource: resource, feedName: customFeedName, collectionId: collectionId, service: service)
		addRequest.delegate = self
		operationQueue.add(addRequest)

		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest)
		createFeeds.addDependency(addRequest)
		operationQueue.add(createFeeds)

		let finishOperation = FeedlyCheckpointOperation()
		finishOperation.checkpointDelegate = self
		finishOperation.addDependency(createFeeds)
		operationQueue.add(finishOperation)
	}

	override func run() {
		operationQueue?.resume()
		didComplete()
	}

	override func noteDidComplete() {
		if isCanceled {
			operationQueue?.cancelAll()
		}
		addCompletionHandler = nil
	}

	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
		addCompletionHandler?(.failure(error))
		addCompletionHandler = nil
	}
	
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
		guard !isCanceled else {
			return
		}
		
		addCompletionHandler?(.success(()))
		addCompletionHandler = nil
		
		didComplete()
	}
}
