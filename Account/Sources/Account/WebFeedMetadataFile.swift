//
//  WebFeedMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

final class WebFeedMetadataFile: Logging {

	private let fileURL: URL
	private let account: Account

	private var isDirty = false {
		didSet {
			queueSaveToDiskIfNeeded()
		}
	}
	private let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)

	init(filename: String, account: Account) {
		self.fileURL = URL(fileURLWithPath: filename)
		self.account = account
	}
	
	func markAsDirty() {
		isDirty = true
	}
	
	func load() {
		if let fileData = try? Data(contentsOf: fileURL) {
			let decoder = PropertyListDecoder()
			account.webFeedMetadata = (try? decoder.decode(Account.WebFeedMetadataDictionary.self, from: fileData)) ?? Account.WebFeedMetadataDictionary()
		}
		account.webFeedMetadata.values.forEach { $0.delegate = account }
	}
	
	func save() {
		guard !account.isDeleted else { return }
		
		let feedMetadata = metadataForOnlySubscribedToFeeds()

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data = try encoder.encode(feedMetadata)
			try data.write(to: fileURL)
		} catch let error {
            logger.error("Save to disk failed: \(error.localizedDescription)")
		}
	}
		
}

private extension WebFeedMetadataFile {

	func queueSaveToDiskIfNeeded() {
		saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	@objc func saveToDiskIfNeeded() {
		if isDirty {
			isDirty = false
			save()
		}
	}

	private func metadataForOnlySubscribedToFeeds() -> Account.WebFeedMetadataDictionary {
		let webFeedIDs = account.idToWebFeedDictionary.keys
		return account.webFeedMetadata.filter { (feedID: String, metadata: WebFeedMetadata) -> Bool in
			return webFeedIDs.contains(metadata.webFeedID)
		}
	}

}
