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
	
	private let fileURL: URL
	private let account: Account
	private let dataFile: DataFile
	private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedMetadataFile")

	init(filename: String, account: Account) {

		self.fileURL = URL(fileURLWithPath: filename)
		self.account = account
		self.dataFile = DataFile(fileURL: self.fileURL)

		self.dataFile.delegate = self
	}
	
	func markAsDirty() {
		
		dataFile.markAsDirty()
	}
	
	func load() {

		if let fileData = try? Data(contentsOf: fileURL) {
			let decoder = PropertyListDecoder()
			account.feedMetadata = (try? decoder.decode(Account.FeedMetadataDictionary.self, from: fileData)) ?? Account.FeedMetadataDictionary()
		}
		account.feedMetadata.values.forEach { $0.delegate = account }
	}

	// Save immediately
	func save() {
		
		dataFile.save()
	}
}

extension FeedMetadataFile: DataFileDelegate {

	func data(for dataFile: DataFile) -> Data? {

		guard !account.isDeleted else {
			return nil
		}

		let feedMetadata = metadataForOnlySubscribedToFeeds()

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		return try? encoder.encode(feedMetadata)
	}

	func dataFileWriteToDiskDidFail(for dataFile: DataFile, error: Error) {

		logger.error("FeedMetadataFile save to disk failed for \(self.fileURL): \(error.localizedDescription)")
	}
}

private extension FeedMetadataFile {

	private func metadataForOnlySubscribedToFeeds() -> Account.FeedMetadataDictionary {

		let feedIDs = account.idToFeedDictionary.keys
		return account.feedMetadata.filter { (feedID: String, metadata: FeedMetadata) -> Bool in
			return feedIDs.contains(metadata.feedID)
		}
	}
}
