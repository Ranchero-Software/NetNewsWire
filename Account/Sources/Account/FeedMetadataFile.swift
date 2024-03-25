//
//  FeedMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Core

@MainActor final class FeedMetadataFile {
	
	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "feedMetadataFile")

	private let fileURL: URL
	private let account: Account

	@MainActor private var isDirty = false {
		didSet {
			queueSaveToDiskIfNeeded()
		}
	}
	@MainActor private let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)

	init(filename: String, account: Account) {
		self.fileURL = URL(fileURLWithPath: filename)
		self.account = account
	}
	
	@MainActor func markAsDirty() {
		isDirty = true
	}
	
	func load() {
		if let fileData = try? Data(contentsOf: fileURL) {
			let decoder = PropertyListDecoder()
			account.feedMetadata = (try? decoder.decode(Account.FeedMetadataDictionary.self, from: fileData)) ?? Account.FeedMetadataDictionary()
		}
		account.feedMetadata.values.forEach { $0.delegate = account }
	}
	
	func save() {
		guard !account.isDeleted else { return }
		
		let feedMetadata = metadataForOnlySubscribedToFeeds()

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data = try encoder.encode(feedMetadata)
			try data.write(to: fileURL)
		} catch let error as NSError {
			os_log(.error, log: log, "Save to disk failed: %@.", error.localizedDescription)
		}
	}
		
}

private extension FeedMetadataFile {

	@MainActor func queueSaveToDiskIfNeeded() {
		saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	@MainActor @objc func saveToDiskIfNeeded() {
		if isDirty {
			isDirty = false
			save()
		}
	}

	private func metadataForOnlySubscribedToFeeds() -> Account.FeedMetadataDictionary {
		let feedIDs = account.idToFeedDictionary.keys
		return account.feedMetadata.filter { (feedID: String, metadata: FeedMetadata) -> Bool in
			return feedIDs.contains(metadata.feedID)
		}
	}

}
