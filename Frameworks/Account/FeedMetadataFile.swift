//
//  FeedMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore

final class FeedMetadataFile {
	
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "feedMetadataFile")

	private let fileURL: URL
	private let account: Account
	private lazy var managedFile = ManagedResourceFile(fileURL: fileURL, load: loadCallback, save: saveCallback)
	
	init(filename: String, account: Account) {
		self.fileURL = URL(fileURLWithPath: filename)
		self.account = account
	}
	
	func markAsDirty() {
		managedFile.markAsDirty()
	}
	
	func load() {
		managedFile.load()
	}
	
	func save() {
		managedFile.saveIfNecessary()
	}
	
}

private extension FeedMetadataFile {

	func loadCallback() {

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: managedFile)
		
		fileCoordinator.coordinate(readingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { readURL in
			if let fileData = try? Data(contentsOf: readURL) {
				let decoder = PropertyListDecoder()
				account.feedMetadata = (try? decoder.decode(Account.FeedMetadataDictionary.self, from: fileData)) ?? Account.FeedMetadataDictionary()
			}
			account.feedMetadata.values.forEach { $0.delegate = account }
			if !account.startingUp {
				account.resetFeedMetadataAndUnreadCounts()
			}
		})
		
		if let error = errorPointer?.pointee {
			os_log(.error, log: log, "Read from disk coordination failed: %@.", error.localizedDescription)
		}
		

	}
	
	func saveCallback() {
		guard !account.isDeleted else { return }
		
		let feedMetadata = metadataForOnlySubscribedToFeeds()

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: managedFile)
		
		fileCoordinator.coordinate(writingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { writeURL in
			do {
				let data = try encoder.encode(feedMetadata)
				try data.write(to: writeURL)
			} catch let error as NSError {
				os_log(.error, log: log, "Save to disk failed: %@.", error.localizedDescription)
			}
		})
		
		if let error = errorPointer?.pointee {
			os_log(.error, log: log, "Save to disk coordination failed: %@.", error.localizedDescription)
		}
	}
	
	private func metadataForOnlySubscribedToFeeds() -> Account.FeedMetadataDictionary {
		let feedIDs = account.idToFeedDictionary.keys
		return account.feedMetadata.filter { (feedID: String, metadata: FeedMetadata) -> Bool in
			return feedIDs.contains(metadata.feedID)
		}
	}

}
