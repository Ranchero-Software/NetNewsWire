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
			account.metadata = (try? decoder.decode(AccountMetadata.self, from: fileData)) ?? AccountMetadata()
		}
		account.metadata.delegate = account
	}
	
	func save() {
		guard !account.isDeleted else { return }
		
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data = try encoder.encode(account.metadata)
			try data.write(to: fileURL)
		} catch let error as NSError {
			os_log(.error, log: log, "Save to disk failed: %@.", error.localizedDescription)
		}
	}
	
}

private extension AccountMetadataFile {

	func queueSaveToDiskIfNeeded() {
		saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	@objc func saveToDiskIfNeeded() {
		if isDirty {
			isDirty = false
			save()
		}
	}

}
