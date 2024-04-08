//
//  FeedlyAddFeedToCollectionOperation.swift
//  Account
//
//  Created by Kiel Gillard on 11/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CommonErrors
import Feedly

protocol FeedlyAddFeedToCollectionService {
	func addFeed(with feedId: FeedlyFeedResourceID, title: String?, toCollectionWith collectionID: String, completion: @escaping (Result<[FeedlyFeed], Error>) -> ())
}

final class FeedlyAddFeedToCollectionOperation: FeedlyOperation, FeedlyFeedsAndFoldersProviding, FeedlyResourceProviding {

	let feedName: String?
	let collectionID: String
	let service: FeedlyAddFeedToCollectionService
	let folder: Folder
	let feedResource: FeedlyFeedResourceID

	init(folder: Folder, feedResource: FeedlyFeedResourceID, feedName: String? = nil, collectionID: String, service: FeedlyAddFeedToCollectionService) {
		self.folder = folder
		self.feedResource = feedResource
		self.feedName = feedName
		self.collectionID = collectionID
		self.service = service
	}
	
	private(set) var feedsAndFolders = [([FeedlyFeed], Folder)]()
	
	var resource: FeedlyResourceID {
		return feedResource
	}
	
	override func run() {
		service.addFeed(with: feedResource, title: feedName, toCollectionWith: collectionID) { [weak self] result in
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
			
			let feedsWithCreatedFeedID = feedlyFeeds.filter { $0.id == resource.id }
			
			if feedsWithCreatedFeedID.isEmpty {
				didFinish(with: AccountError.createErrorNotFound)
			} else {
				didFinish()
			}
			
		case .failure(let error):
			didFinish(with: error)
		}
	}
}
