//
//  FeedlyMirrorCollectionsAsFoldersOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyCollectionsAndFoldersProviding: class {
	var collectionsAndFolders: [(FeedlyCollection, Folder)] { get }
}

/// Single responsibility is accurately reflect Collections from Feedly as Folders.
final class FeedlyMirrorCollectionsAsFoldersOperation: FeedlySyncOperation, FeedlyCollectionsAndFoldersProviding {
	
	let caller: FeedlyAPICaller
	let account: Account
	let collectionsProvider: FeedlyCollectionProviding
	
	private(set) var collectionsAndFolders = [(FeedlyCollection, Folder)]()
	
	init(account: Account, collectionsProvider: FeedlyCollectionProviding, caller: FeedlyAPICaller) {
		self.collectionsProvider = collectionsProvider
		self.account = account
		self.caller = caller
	}
	
	override func main() {
		defer { didFinish() }
		
		guard !isCancelled else { return }
		
		let localFolders = account.folders ?? Set()
		let collections = collectionsProvider.collections
		
		let pairs = collections.compactMap { collection -> (FeedlyCollection, Folder)? in
			for folder in localFolders {
				if folder.name == collection.label {
					return (collection, folder)
				}
			}
			
			guard let newFolder = account.ensureFolder(with: collection.label) else {
				assertionFailure("Try debugging why a folder could not be created.")
				return nil
			}
			
			return (collection, newFolder)
		}
		
		collectionsAndFolders = pairs
		
		// Remove folders without a corresponding collection
		let collectionFolders = Set(pairs.map { $0.1 })
		let foldersWithoutCollections = localFolders.subtracting(collectionFolders)
		for unmatched in foldersWithoutCollections {
			account.removeFolder(unmatched)
		}
	}
}
