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
	private let fileURL: URL
	private let account: Account

	@MainActor private var isDirty = false {
		didSet {
			queueSaveToDiskIfNeeded()
		}
	}
	private let saveQueue = CoalescingQueue(name: "Save Queue", interval: 0.5)
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccountMetadataFile")

	init(filename: String, account: Account) {
		self.fileURL = URL(fileURLWithPath: filename)
		self.account = account
	}

	@MainActor func markAsDirty() {
		isDirty = true
	}

	@MainActor func load() {
		if let fileData = try? Data(contentsOf: fileURL) {
			let decoder = PropertyListDecoder()
			account.metadata = (try? decoder.decode(AccountMetadata.self, from: fileData)) ?? AccountMetadata()
		}
		account.metadata.delegate = account
	}

	@MainActor func save() {
		guard !account.isDeleted else { return }

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		do {
			let data = try encoder.encode(account.metadata)
			try data.write(to: fileURL)
		} catch let error as NSError {
			Self.logger.error("AccountMetadataFile accountID: \(self.account.accountID) save to disk failed: \(error.localizedDescription)")
		}
	}

}

private extension AccountMetadataFile {

	@MainActor func queueSaveToDiskIfNeeded() {
		saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	@MainActor @objc func saveToDiskIfNeeded() {
		if isDirty {
			isDirty = false
			save()
		}
	}
}
