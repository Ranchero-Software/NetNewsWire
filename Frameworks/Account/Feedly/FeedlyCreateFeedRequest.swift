//
//  FeedlyCreateFeedRequest.swift
//  Account
//
//  Created by Kiel Gillard on 10/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

final class FeedlyCreateFeedRequest {
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
	
	func start(url: String, name: String?, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		let (folder, collectionId): (Folder, String)
		do {
			let validator = FeedlyFeedContainerValidator(container: container, userId: caller.credentials?.username)
			(folder, collectionId) = try validator.getValidContainer()
		} catch {
			return DispatchQueue.main.async {
				completion(.failure(error))
			}
		}
		
		let subscribeRequest = FeedlySubscribeToFeedOperation(account: account, folder: folder, url: url, feedName: name, collectionId: collectionId, caller: caller)
		
		let delegate = Delegate(resourceProvider: subscribeRequest)
		delegate.completionHandler = completion
		
		let createFeed = FeedlyCompoundOperation() {
			let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: subscribeRequest, log: log)
			let getStream = FeedlyGetStreamOperation(account: account, resourceProvider: subscribeRequest, caller: caller, newerThan: nil)
			let organiseByFeed = FeedlyOrganiseParsedItemsByFeedOperation(account: account, entryProvider: getStream, log: log)
			let updateAccount = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: organiseByFeed, log: log)
			
			createFeeds.addDependency(subscribeRequest)
			getStream.addDependency(createFeeds)
			organiseByFeed.addDependency(getStream)
			updateAccount.addDependency(organiseByFeed)
			
			let operations = [subscribeRequest, createFeeds, getStream, organiseByFeed, updateAccount]
			
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
				
			} else if let feed = folder.existingFeed(withFeedID: subscribeRequest.resource.id) {
				handler(.success(feed))
				
			} else {
				handler(.failure(AccountError.createErrorNotFound))
			}
		}
		
		callback.addDependency(createFeed)
		
		OperationQueue.main.addOperations([createFeed, callback], waitUntilFinished: false)
	}
}
