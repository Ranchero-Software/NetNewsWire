//
//  AccountSettingsDatabase.swift
//  Account
//
//  Created by Brent Simmons on 3/6/26.
//

// TODO: Delete this file in 7.2.

import Foundation
import RSDatabaseObjC

@MainActor final class AccountSettingsDatabase {

	private struct AccountCredentials {
		let username: String?
		let endpointURL: String?
	}

	private let credentialsByAccountID: [String: AccountCredentials]

	init?(databasePath: String) {
		guard FileManager.default.fileExists(atPath: databasePath) else {
			return nil
		}

		guard let database = FMDatabase(path: databasePath), database.open() else {
			return nil
		}
		defer {
			database.close()
		}

		var credentials = [String: AccountCredentials]()

		if let resultSet = database.executeQuery("SELECT accountID, username, endpointURL FROM accountSettings;", withArgumentsIn: []) {
			while resultSet.next() {
				guard let accountID = resultSet.string(forColumn: "accountID") else {
					continue
				}
				let username = resultSet.string(forColumn: "username")
				let endpointURL = resultSet.string(forColumn: "endpointURL")
				if username != nil || endpointURL != nil {
					credentials[accountID] = AccountCredentials(username: username, endpointURL: endpointURL)
				}
			}
			resultSet.close()
		}

		self.credentialsByAccountID = credentials
	}

	func username(for accountID: String) -> String? {
		credentialsByAccountID[accountID]?.username
	}

	func endpointURL(for accountID: String) -> String? {
		credentialsByAccountID[accountID]?.endpointURL
	}
}
