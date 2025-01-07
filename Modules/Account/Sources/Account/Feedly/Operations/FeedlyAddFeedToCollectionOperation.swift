//
//  FeedlyAddFeedToCollectionOperation.swift
//  Account
//
//  Created by Kiel Gillard on 11/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyAddFeedToCollectionService {
	func addFeed(with feedId: FeedlyFeedResourceId, title: String?, toCollectionWith collectionId: String, completion: @escaping (Result<[FeedlyFeed], Error>) -> ())
}

final class FeedlyAddFeedToCollectionOperation: FeedlyOperation, FeedlyFeedsAndFoldersProviding, FeedlyResourceProviding {

	let feedName: String?
	let collectionId: String
	let service: FeedlyAddFeedToCollectionService
	let account: Account
	let folder: Folder
	let feedResource: FeedlyFeedResourceId

	init(account: Account, folder: Folder, feedResource: FeedlyFeedResourceId, feedName: String? = nil, collectionId: String, service: FeedlyAddFeedToCollectionService) {
		self.account = account
		self.folder = folder
		self.feedResource = feedResource
		self.feedName = feedName
		self.collectionId = collectionId
		self.service = service
	}
	
	private(set) var feedsAndFolders = [([FeedlyFeed], Folder)]()
	
	var resource: FeedlyResourceId {
		return feedResource
	}
	
	override func run() {
		service.addFeed(with: feedResource, title: feedName, toCollectionWith: collectionId) { [weak self] result in
			guard let self = self else {
				return
			}
			if self.isCanceled {
				self.didFinish()
				return
			}
			self.didCompleteRequest(result)
		}
	}
}

private extension FeedlyAddFeedToCollectionOperation {

	func didCompleteRequest(_ result: Result<[FeedlyFeed], Error>) {
		switch result {
		case .success(let feedlyFeeds):
			feedsAndFolders = [(feedlyFeeds, folder)]
			
			let feedsWithCreatedFeedId = feedlyFeeds.filter { $0.id == resource.id }
			
			if feedsWithCreatedFeedId.isEmpty {
				didFinish(with: AccountError.createErrorNotFound)
			} else {
				didFinish()
			}
			
		case .failure(let error):
			didFinish(with: error)
		}
	}
}
