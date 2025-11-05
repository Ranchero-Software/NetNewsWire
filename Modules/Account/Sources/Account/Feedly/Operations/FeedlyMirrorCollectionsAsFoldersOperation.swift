//
//  FeedlyMirrorCollectionsAsFoldersOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyFeedsAndFoldersProviding {
	var feedsAndFolders: [([FeedlyFeed], Folder)] { get }
}

/// Reflect Collections from Feedly as Folders.
final class FeedlyMirrorCollectionsAsFoldersOperation: FeedlyOperation, FeedlyFeedsAndFoldersProviding {

	let account: Account
	let collectionsProvider: FeedlyCollectionProviding

	private(set) var feedsAndFolders = [([FeedlyFeed], Folder)]()

	init(account: Account, collectionsProvider: FeedlyCollectionProviding) {
		self.collectionsProvider = collectionsProvider
		self.account = account
	}

	override func run() {
		defer {
			didFinish()
		}

		let localFolders = account.folders ?? Set()
		let collections = collectionsProvider.collections

		feedsAndFolders = collections.compactMap { collection -> ([FeedlyFeed], Folder)? in
			let parser = FeedlyCollectionParser(collection: collection)
			guard let folder = account.ensureFolder(with: parser.folderName) else {
				assertionFailure("Why wasn't a folder created?")
				return nil
			}
			folder.externalID = parser.externalID
			return (collection.feeds, folder)
		}

		Feedly.logger.info("Feedly: Ensured \(self.feedsAndFolders.count) folders for \(collections.count) collections")

		// Remove folders without a corresponding collection
		let collectionFolders = Set(feedsAndFolders.map { $0.1 })
		let foldersWithoutCollections = localFolders.subtracting(collectionFolders)

		if !foldersWithoutCollections.isEmpty {
			for unmatched in foldersWithoutCollections {
				account.removeFolder(unmatched)
			}

			let folderCountForLog = foldersWithoutCollections.count
			let foldersForLog = foldersWithoutCollections.map { $0.externalID ?? $0.nameForDisplay }
			Feedly.logger.info("Feedly: Removed \(folderCountForLog) folders: \(foldersForLog)")
		}
	}
}
