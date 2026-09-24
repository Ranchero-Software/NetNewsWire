//
//  TestAccountManager.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import Secrets

@testable import Account

@MainActor final class TestAccountManager {

	nonisolated static let shared = TestAccountManager()

	// Not Caches: macOS puts a `group:everyone deny delete` ACE on it, so test accounts
	// created there can't be removed afterward.
	private let accountsFolder = FileManager.default.temporaryDirectory.appendingPathComponent("NetNewsWireTestAccounts")

	func createAccount(type: AccountType, username: String? = nil, password: String? = nil) -> Account {

		let accountID = UUID().uuidString
		let accountFolder = accountsFolder.appendingPathComponent("\(type.rawValue)_\(accountID)")

		do {
			try FileManager.default.createDirectory(at: accountFolder, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for \(accountID) account.")
			abort()
		}

		let account = Account(dataFolder: accountFolder.path, type: type, accountID: accountID)

		return account
	}

	func deleteAccount(_ account: Account) {

		// Credentials live in the keychain, outside the account folder removed below.
		for credentialsType in CredentialsType.allCases {
			try? account.removeCredentials(type: credentialsType)
		}

		account.deleteSettings()

		// Cleanup failing is not a test failure, and aborting here would take every
		// other test in the process down with it.
		try? FileManager.default.removeItem(atPath: account.dataFolder)
	}
}
