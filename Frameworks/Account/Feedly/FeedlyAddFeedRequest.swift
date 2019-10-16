//
//  FeedlyCreateFeedRequest.swift
//  Account
//
//  Created by Kiel Gillard on 10/10/19.
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
	
	func addNewFeed(at url: String, name: String? = nil, completion: @escaping (Result<Feed, Error>) -> Void) {
		let resource = FeedlyFeedResourceId(url: url)
		self.start(resource: resource, name: name, refreshes: true, completion: completion)
	}
	
	func add(existing feed: Feed, name: String? = nil, completion: @escaping (Result<Feed, Error>) -> Void) {
		let resource = FeedlyFeedResourceId(id: feed.feedID)
		self.start(resource: resource, name: name, refreshes: false, completion: completion)
	}
	
	private func start(resource: FeedlyFeedResourceId, name: String?, refreshes: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		
		let (folder, collectionId): (Folder, String)
		do {
			let validator = FeedlyFeedContainerValidator(container: container, userId: caller.credentials?.username)
			(folder, collectionId) = try validator.getValidContainer()
		} catch {
			return DispatchQueue.main.async {
				completion(.failure(error))
			}
		}
		
		let delegate = Delegate(resourceProvider: resource)
		delegate.completionHandler = completion
		
		let createFeed = FeedlyCompoundOperation() {
			let addRequest = FeedlyAddFeedOperation(account: account, folder: folder, feedResource: resource, feedName: name, collectionId: collectionId, caller: caller)
			
			let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addRequest, log: log)
			createFeeds.addDependency(addRequest)
			
			let getStream: FeedlyGetStreamOperation? = {
				if refreshes {
					let op = FeedlyGetStreamOperation(account: account, resourceProvider: addRequest, caller: caller, newerThan: nil)
					op.addDependency(createFeeds)
					return op
				}
				return nil
			}()
			
			let organiseByFeed: FeedlyOrganiseParsedItemsByFeedOperation? = {
				if let getStream = getStream {
					let op = FeedlyOrganiseParsedItemsByFeedOperation(account: account, entryProvider: getStream, log: log)
					op.addDependency(getStream)
					return op
				}
				return nil
			}()
			
			let updateAccount: FeedlyUpdateAccountFeedsWithItemsOperation? = {
				if let organiseByFeed = organiseByFeed {
					let op = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: organiseByFeed, log: log)
					op.addDependency(organiseByFeed)
					return op
				}
				return nil
			}()
			
			let operations = [addRequest, createFeeds, getStream, organiseByFeed, updateAccount].compactMap { $0 }
			
			for operation in operations {
				assert(operation.isReady == (operation === addRequest), "Only the add request operation should be ready.")
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
		
		callback.addDependency(createFeed)
		
		OperationQueue.main.addOperations([createFeed, callback], waitUntilFinished: false)
	}
}
