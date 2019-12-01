//
//  WebFeedMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore

final class WebFeedMetadataFile {
	
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "webFeedMetadataFile")

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
	
	func suspend() {
		managedFile.suspend()
	}
	
	func resume() {
		managedFile.resume()
	}
	
}

private extension WebFeedMetadataFile {

	func loadCallback() {

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: managedFile)
		
		fileCoordinator.coordinate(readingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { readURL in
			if let fileData = try? Data(contentsOf: readURL) {
				let decoder = PropertyListDecoder()
				account.webFeedMetadata = (try? decoder.decode(Account.WebFeedMetadataDictionary.self, from: fileData)) ?? Account.WebFeedMetadataDictionary()
			}
			account.webFeedMetadata.values.forEach { $0.delegate = account }
			if !account.startingUp {
				account.resetWebFeedMetadataAndUnreadCounts()
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
	
	private func metadataForOnlySubscribedToFeeds() -> Account.WebFeedMetadataDictionary {
		let webFeedIDs = account.idToWebFeedDictionary.keys
		return account.webFeedMetadata.filter { (feedID: String, metadata: WebFeedMetadata) -> Bool in
			return webFeedIDs.contains(metadata.webFeedID)
		}
	}

}
