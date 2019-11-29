//
//  FeedlyAddFeedToCollectionOperation.swift
//  Account
//
//  Created by Kiel Gillard on 11/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

final class FeedlyAddFeedToCollectionOperation: FeedlyOperation, FeedlyFeedsAndFoldersProviding, FeedlyResourceProviding {
	let feedName: String?
	let collectionId: String
	let caller: FeedlyAPICaller
	let account: Account
	let folder: Folder
	let feedResource: FeedlyFeedResourceId
	
	init(account: Account, folder: Folder, feedResource: FeedlyFeedResourceId, feedName: String? = nil, collectionId: String, caller: FeedlyAPICaller) {
		self.account = account
		self.folder = folder
		self.feedResource = feedResource
		self.feedName = feedName
		self.collectionId = collectionId
		self.caller = caller
	}
	
	private(set) var feedsAndFolders = [([FeedlyFeed], Folder)]()
	
	var resource: FeedlyResourceId {
		return feedResource
	}
	
	override func main() {
		guard !isCancelled else {
			return didFinish()
		}
		
		caller.addFeed(with: feedResource, title: feedName, toCollectionWith: collectionId) { [weak self] result in
			guard let self = self else {
				return
			}
			guard !self.isCancelled else {
				return self.didFinish()
			}
			self.didCompleteRequest(result)
		}
	}
	
	private func didCompleteRequest(_ result: Result<[FeedlyFeed], Error>) {
		switch result {
		case .success(let feedlyFeeds):
			feedsAndFolders = [(feedlyFeeds, folder)]
			
			let feedsWithCreatedFeedId = feedlyFeeds.filter { $0.feedId == resource.id }
			
			if feedsWithCreatedFeedId.isEmpty {
				didFinish(AccountError.createErrorNotFound)
			} else {
				didFinish()
			}
			
		case .failure(let error):
			didFinish(error)
		}
	}
}
