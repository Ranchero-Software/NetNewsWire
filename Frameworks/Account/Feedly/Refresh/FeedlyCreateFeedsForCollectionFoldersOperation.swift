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
					if feed.feedID == collectionFeed.feedId {
						return (feed, folder)
					}
				}

				// no exsiting feed, create a new one
				let url = collectionFeed.id
				let metadata = FeedMetadata(feedID: url)
				// TODO: More metadata
								
				let feed = Feed(account: account, url: url, metadata: metadata)
				feed.name = collectionFeed.title
				
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
		
		let feedsAfter = Set(feedsAndFolders.map { $0.0 })
		let feedsWithoutCollections = feedsBefore.subtracting(feedsAfter)
		for unmatched in feedsWithoutCollections {
			account.removeFeed(unmatched)
		}
		
		if !feedsWithoutCollections.isEmpty {
			os_log(.debug, log: log, "Removed %i feeds", feedsWithoutCollections.count)
		}
	}
}
