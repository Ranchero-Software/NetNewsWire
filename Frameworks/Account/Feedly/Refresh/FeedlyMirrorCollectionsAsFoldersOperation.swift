//
//  FeedlyMirrorCollectionsAsFoldersOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

protocol FeedlyCollectionsAndFoldersProviding: class {
	var collectionsAndFolders: [(FeedlyCollection, Folder)] { get }
}

protocol FeedlyFeedsAndFoldersProviding {
	var feedsAndFolders: [([FeedlyFeed], Folder)] { get }
}

/// Single responsibility is accurately reflect Collections from Feedly as Folders.
final class FeedlyMirrorCollectionsAsFoldersOperation: FeedlyOperation, FeedlyCollectionsAndFoldersProviding, FeedlyFeedsAndFoldersProviding {
	
	let caller: FeedlyAPICaller
	let account: Account
	let collectionsProvider: FeedlyCollectionProviding
	let log: OSLog
	
	private(set) var collectionsAndFolders = [(FeedlyCollection, Folder)]()
	private(set) var feedsAndFolders = [([FeedlyFeed], Folder)]()
	
	init(account: Account, collectionsProvider: FeedlyCollectionProviding, caller: FeedlyAPICaller, log: OSLog) {
		self.collectionsProvider = collectionsProvider
		self.account = account
		self.caller = caller
		self.log = log
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else { return }
		
		let localFolders = account.folders ?? Set()
		let collections = collectionsProvider.collections
		
		let pairs = collections.compactMap { collection -> (FeedlyCollection, Folder)? in
			guard let folder = account.ensureFolder(with: collection.label) else {
				assertionFailure("Why wasn't a folder created?")
				return nil
			}
			folder.externalID = collection.id
			return (collection, folder)
		}
		
		collectionsAndFolders = pairs
		os_log(.debug, log: log, "Ensured %i folders for %i collections.", pairs.count, collections.count)
		
		feedsAndFolders = pairs.map { (collection, folder) -> (([FeedlyFeed], Folder)) in
			return (collection.feeds, folder)
		}
		
		// Remove folders without a corresponding collection
		let collectionFolders = Set(pairs.map { $0.1 })
		let foldersWithoutCollections = localFolders.subtracting(collectionFolders)
		for unmatched in foldersWithoutCollections {
			account.removeFolder(unmatched)
		}
		
		os_log(.debug, log: log, "Removed %i folders: %@", foldersWithoutCollections.count, foldersWithoutCollections.map { $0.externalID ?? $0.nameForDisplay })
	}
}
