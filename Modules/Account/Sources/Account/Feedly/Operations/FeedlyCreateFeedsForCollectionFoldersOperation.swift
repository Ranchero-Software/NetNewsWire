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
	let feedsAndFoldersProvider: FeedlyFeedsAndFoldersProviding

	init(account: Account, feedsAndFoldersProvider: FeedlyFeedsAndFoldersProviding) {
		self.feedsAndFoldersProvider = feedsAndFoldersProvider
		self.account = account
	}

	override func run() {
		defer {
			didFinish()
		}

		let pairs = feedsAndFoldersProvider.feedsAndFolders

		let feedsBefore = Set(pairs
			.map { $0.1 }
			.flatMap { $0.topLevelFeeds })

		// Remove feeds in a folder which are not in the corresponding collection.
		for (collectionFeeds, folder) in pairs {
			let feedsInFolder = folder.topLevelFeeds
			let feedsInCollection = Set(collectionFeeds.map { $0.id })
			let feedsToRemove = feedsInFolder.filter { !feedsInCollection.contains($0.feedID) }
			if !feedsToRemove.isEmpty {
				folder.removeFeedsFromTreeAtTopLevel(feedsToRemove)
				//				os_log(.debug, log: log, "\"%@\" - removed: %@", collection.label, feedsToRemove.map { $0.feedID }, feedsInCollection)
			}

		}

		// Pair each Feed with its Folder.
		var feedsAdded = Set<Feed>()

		let feedsAndFolders = pairs
			.map({ (collectionFeeds, folder) -> [(FeedlyFeed, Folder)] in
				return collectionFeeds.map { feed -> (FeedlyFeed, Folder) in
					return (feed, folder) // pairs a folder for every feed in parallel
				}
			})
			.flatMap { $0 }
			.compactMap { (collectionFeed, folder) -> (Feed, Folder) in

				// find an existing feed previously added to the account
				if let feed = account.existingFeed(withFeedID: collectionFeed.id) {

					// If the feed was renamed on Feedly, ensure we ingest the new name.
					if feed.nameForDisplay != collectionFeed.title {
						feed.name = collectionFeed.title

						// Let the rest of the app (e.g.: the sidebar) know the feed name changed
						// `editedName` would post this if its value is changing.
						// Setting the `name` property has no side effects like this.
						if feed.editedName != nil {
							feed.editedName = nil
						} else {
							feed.postDisplayNameDidChangeNotification()
						}
					}
					return (feed, folder)
				} else {
					// find an existing feed we created below in an earlier value
					for feed in feedsAdded where feed.feedID == collectionFeed.id {
						return (feed, folder)
					}
				}

				// no existing feed, create a new one
				let parser = FeedlyFeedParser(feed: collectionFeed)
				let feed = account.createFeed(with: parser.title,
												 url: parser.url,
												 feedID: parser.feedID,
												 homePageURL: parser.homePageURL)

				// So the same feed isn't created more than once.
				feedsAdded.insert(feed)

				return (feed, folder)
			}

		Feedly.logger.info("Feedly: Processing \(feedsAndFolders.count) feeds")
		feedsAndFolders.forEach { (feed, folder) in
			if !folder.has(feed) {
				folder.addFeedToTreeAtTopLevel(feed)
			}
		}

		// Remove feeds without folders/collections.
		let feedsAfter = Set(feedsAndFolders.map { $0.0 })
		let feedsWithoutCollections = feedsBefore.subtracting(feedsAfter)
		account.removeFeedsFromTreeAtTopLevel(feedsWithoutCollections)

		if !feedsWithoutCollections.isEmpty {
			Feedly.logger.info("Feedly: Removed \(feedsWithoutCollections.count) feeds")
		}
	}
}
