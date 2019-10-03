//
//  FeedlyCreateFeedsForCollectionFoldersOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

/// Single responsibility is to accurately reflect Collections and their Feeds as Folders and their Feeds.
final class FeedlyCreateFeedsForCollectionFoldersOperation: FeedlyOperation {
	
	let account: Account
	let collectionsAndFoldersProvider: FeedlyCollectionsAndFoldersProviding
	let log: OSLog
		
	init(account: Account, collectionsAndFoldersProvider: FeedlyCollectionsAndFoldersProviding, log: OSLog) {
		self.collectionsAndFoldersProvider = collectionsAndFoldersProvider
		self.account = account
		self.log = log
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else { return }

		var localFeeds = account.flattenedFeeds()
		let feedsBefore = localFeeds
		let pairs = collectionsAndFoldersProvider.collectionsAndFolders
		
		// Remove feeds in a folder which are not in the corresponding collection.
		for (collection, folder) in pairs {
			let feedsInFolder = folder.topLevelFeeds
			let feedsInCollection = Set(collection.feeds.map { $0.id })
			let feedsToRemove = feedsInFolder.filter { !feedsInCollection.contains($0.feedID) }
			if !feedsToRemove.isEmpty {
				folder.removeFeeds(feedsToRemove)
				os_log(.debug, log: log, "\"%@\" - removed: %@", collection.label, feedsToRemove.map { $0.feedID }, feedsInCollection)
			}
			
		}
		
		// Pair each Feed with its Folder.
		let feedsAndFolders = pairs
			.compactMap { ($0.0.feeds, $0.1) }
			.map({ (collectionFeeds, folder) -> [(FeedlyFeed, Folder)] in
				return collectionFeeds.map { feed -> (FeedlyFeed, Folder) in
					return (feed, folder) // pairs a folder for every feed in parallel
				}
			})
			.flatMap { $0 }
			.compactMap { (collectionFeed, folder) -> (Feed, Folder) in

				// find an existing feed
				for feed in localFeeds {
					if feed.feedID == collectionFeed.id {
						return (feed, folder)
					}
				}

				// no exsiting feed, create a new one
				let id = collectionFeed.id
				let url = FeedlyFeedResourceId(id: id).url
				let feed = account.createFeed(with: collectionFeed.title, url: url, feedID: id, homePageURL: collectionFeed.website)
				
				// So the same feed isn't created more than once.
				localFeeds.insert(feed)
				
				return (feed, folder)
			}
		
		os_log(.debug, log: log, "Processing %i feeds.", feedsAndFolders.count)
		feedsAndFolders.forEach { (feed, folder) in
			if !folder.has(feed) {
				folder.addFeed(feed)
			}
		}
		
		// Remove feeds without folders/collections.
		let feedsAfter = Set(feedsAndFolders.map { $0.0 })
		let feedsWithoutCollections = feedsBefore.subtracting(feedsAfter)
		account.removeFeeds(feedsWithoutCollections)
		
		if !feedsWithoutCollections.isEmpty {
			os_log(.debug, log: log, "Removed %i feeds", feedsWithoutCollections.count)
		}
	}
}
