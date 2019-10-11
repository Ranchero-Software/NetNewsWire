//
//  FeedlyAddFeedRequest.swift
//  Account
//
//  Created by Kiel Gillard on 11/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

final class FeedlyAddFeedRequest {
	let account: Account
	let caller: FeedlyAPICaller
	let container: Container
	let log: OSLog
	
	init(account: Account, caller: FeedlyAPICaller, container: Container, log: OSLog) {
		self.account = account
		self.caller = caller
		self.container = container
		self.log = log
	}
	
	private class Delegate: FeedlyOperationDelegate {
		let resourceProvider: FeedlyResourceProviding
		
		init(resourceProvider: FeedlyResourceProviding) {
			self.resourceProvider = resourceProvider
		}
		
		var completionHandler: ((Result<Feed, Error>) -> ())?
		var error: Error?
		
		func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
			self.error = error
		}
	}
	
	func start(adding feed: Feed, to container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		let (folder, collectionId): (Folder, String)
		do {
			let validator = FeedlyFeedContainerValidator(container: container, userId: caller.credentials?.username)
			(folder, collectionId) = try validator.getValidContainer()
		} catch {
			return DispatchQueue.main.async {
				completion(.failure(error))
			}
		}
		
		let resource = FeedlyFeedResourceId(id: feed.feedID)
		
		let delegate = Delegate(resourceProvider: resource)
		delegate.completionHandler = completion
		
		let addFeed = FeedlyCompoundOperation() {
			let addRequest = FeedlyAddFeedOperation(account: account, folder: folder, feedResource: resource, collectionId: collectionId, caller: caller)
			
			let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest, log: log)
			
			createFeeds.addDependency(addRequest)
			
			let operations = [addRequest, createFeeds]
			
			for operation in operations {
				operation.delegate = delegate
			}
			
			return operations
		}
				
		let callback = BlockOperation() {
			guard let handler = delegate.completionHandler else {
				return
			}
			
			defer { delegate.completionHandler = nil }
			
			if let error = delegate.error {
				handler(.failure(error))
				
			} else if let feed = folder.existingFeed(withFeedID: resource.id) {
				handler(.success(feed))
				
			} else {
				handler(.failure(AccountError.createErrorNotFound))
			}
		}
		
		callback.addDependency(addFeed)
		
		OperationQueue.main.addOperations([addFeed, callback], waitUntilFinished: false)
	}
}
