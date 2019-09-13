//
//  AccountMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore

final class AccountMetadataFile {
	
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "accountMetadataFile")

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
	
	func queueSaveToDiskIfNeeded() {
		managedFile.queueSaveToDiskIfNeeded()
	}

	func load() {
		managedFile.load()
	}
	
}

private extension AccountMetadataFile {

	func loadCallback() {

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: managedFile)
		
		fileCoordinator.coordinate(readingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { readURL in
			if let fileData = try? Data(contentsOf: readURL) {
				let decoder = PropertyListDecoder()
				account.metadata = (try? decoder.decode(AccountMetadata.self, from: fileData)) ?? AccountMetadata()
			}
		})
		
		if let error = errorPointer?.pointee {
			os_log(.error, log: log, "Read from disk coordination failed: %@.", error.localizedDescription)
		}
		
		account.metadata.delegate = account
	}
	
	func saveCallback() {
		guard !account.isDeleted else { return }
		
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		let errorPointer: NSErrorPointer = nil
		let fileCoordinator = NSFileCoordinator(filePresenter: managedFile)
		
		fileCoordinator.coordinate(writingItemAt: fileURL, options: [], error: errorPointer, byAccessor: { writeURL in
			do {
				let data = try encoder.encode(account.metadata)
				try data.write(to: writeURL)
			} catch let error as NSError {
				os_log(.error, log: log, "Save to disk failed: %@.", error.localizedDescription)
			}
		})
		
		if let error = errorPointer?.pointee {
			os_log(.error, log: log, "Save to disk coordination failed: %@.", error.localizedDescription)
		}
	}
	
}
