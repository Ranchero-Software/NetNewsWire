//
//  AccountMetadataFile.swift
//  Account
//
//  Created by Maurice Parker on 9/13/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Core

@MainActor final class AccountMetadataFile {

	private let fileURL: URL
	private let account: Account
	private let dataFile: DataFile
	private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccountMetadataFile")

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
			account.metadata = (try? decoder.decode(AccountMetadata.self, from: fileData)) ?? AccountMetadata()
		}
		account.metadata.delegate = account
	}
	
	func save() {

		dataFile.save()
	}
}

extension AccountMetadataFile: DataFileDelegate {

	func data(for dataFile: DataFile) -> Data? {

		guard !account.isDeleted else {
			return nil
		}

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary

		return try? encoder.encode(account.metadata)
	}

	func dataFileWriteToDiskDidFail(for dataFile: DataFile, error: Error) {
		
		logger.error("AccountMetadataFile save to disk failed for \(self.fileURL): \(error.localizedDescription)")
	}
}
