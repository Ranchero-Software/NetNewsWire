//
//  FeedlyFolderReconciliation.swift
//  Account
//
//  Created by Brent Simmons on 5/29/26.
//

import Foundation

/// Pure helpers that reconcile Feedly collections/feeds with `Account`'s folders and feeds.
/// Extracted so they're directly testable without the surrounding sync machinery.

/// Ensure the account has one folder per collection and remove folders that no longer
/// have a corresponding collection.
///
/// Returns one `(feeds, folder)` pair per collection so callers can sync feed membership.
@MainActor func mirrorCollectionsAsFolders(_ collections: [FeedlyCollection], in account: Account) -> [(feeds: [FeedlyFeed], folder: Folder)] {

	let localFolders = account.folders ?? Set()

	let pairs: [(feeds: [FeedlyFeed], folder: Folder)] = collections.compactMap { collection in
		let parser = FeedlyCollectionParser(collection: collection)
		guard let folder = account.ensureFolder(with: parser.folderName) else {
			assertionFailure("Why wasn't a folder created?")
			return nil
		}
		folder.externalID = parser.externalID
		return (collection.feeds, folder)
	}

	Feedly.logger.info("Feedly: Ensured \(pairs.count) folders for \(collections.count) collections")

	// Remove folders without a corresponding collection.
	let collectionFolders = Set(pairs.map { $0.folder })
	let foldersWithoutCollections = localFolders.subtracting(collectionFolders)

	if !foldersWithoutCollections.isEmpty {
		for unmatched in foldersWithoutCollections {
			account.removeFolderFromTree(unmatched)
		}
		let folderCountForLog = foldersWithoutCollections.count
		let foldersForLog = foldersWithoutCollections.map { $0.externalID ?? $0.nameForDisplay }
		Feedly.logger.info("Feedly: Removed \(folderCountForLog) folders: \(foldersForLog)")
	}

	return pairs
}

/// Reconcile each folder's feed membership against the Feedly collection that produced it,
/// creating new feeds as needed and updating renamed ones.
@MainActor func syncFeedsForCollectionFolders(_ pairs: [(feeds: [FeedlyFeed], folder: Folder)], in account: Account) {

	let feedsBefore = Set(pairs
		.map { $0.folder }
		.flatMap { $0.topLevelFeeds })

	// Remove feeds in a folder that no longer appear in the corresponding collection.
	for (collectionFeeds, folder) in pairs {
		let feedsInFolder = folder.topLevelFeeds
		let feedsInCollection = Set(collectionFeeds.map { $0.id })
		let feedsToRemove = feedsInFolder.filter { !feedsInCollection.contains($0.feedID) }
		if !feedsToRemove.isEmpty {
			folder.removeFeedsFromTreeAtTopLevel(feedsToRemove)
		}
	}

	// Pair each Feedly feed with its folder, reusing existing Feed instances and creating
	// new ones (once each) for feeds the account doesn't yet have.
	var feedsAdded = Set<Feed>()

	let feedsAndFolders: [(Feed, Folder)] = pairs
		.flatMap { (collectionFeeds, folder) in
			collectionFeeds.map { (feed: $0, folder: folder) }
		}
		.compactMap { (collectionFeed, folder) -> (Feed, Folder) in

			if let feed = account.existingFeed(withFeedID: collectionFeed.id) {
				// If the feed was renamed on Feedly, ingest the new name.
				if feed.nameForDisplay != collectionFeed.title {
					feed.name = collectionFeed.title

					// Let the rest of the app (e.g. the sidebar) know the name changed.
					// Setting `editedName` would post this; setting `name` does not.
					if feed.editedName != nil {
						feed.editedName = nil
					} else {
						feed.postDisplayNameDidChangeNotification()
					}
				}
				return (feed, folder)
			}

			// Reuse a feed we created earlier in this same pass.
			if let existing = feedsAdded.first(where: { $0.feedID == collectionFeed.id }) {
				return (existing, folder)
			}

			let parser = FeedlyFeedParser(feed: collectionFeed)
			let feed = account.createFeed(with: parser.title, url: parser.url, feedID: parser.feedID, homePageURL: parser.homePageURL)
			feedsAdded.insert(feed)
			return (feed, folder)
		}

	Feedly.logger.info("Feedly: Processing \(feedsAndFolders.count) feeds")

	for (feed, folder) in feedsAndFolders {
		if !folder.has(feed) {
			folder.addFeedToTreeAtTopLevel(feed)
		}
	}

	// Remove feeds that previously sat in a folder but no longer have one.
	let feedsAfter = Set(feedsAndFolders.map { $0.0 })
	let feedsWithoutCollections = feedsBefore.subtracting(feedsAfter)
	account.removeFeedsFromTreeAtTopLevel(feedsWithoutCollections)

	if !feedsWithoutCollections.isEmpty {
		Feedly.logger.info("Feedly: Removed \(feedsWithoutCollections.count) feeds")
	}
}
