//
//  AccountSettings.swift
//  Account
//
//  Created by Brent Simmons on 3/3/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

/// AccountSettings is backed by AccountSettingsDatabase.
/// Setting a property here will save it immediately.
@MainActor final class AccountSettings {
	private let accountID: String
	private let database: AccountSettingsDatabase

	var name: String? {
		didSet {
			if name != oldValue {
				database.setString(name, for: accountID, column: .name)
			}
		}
	}

	var isActive: Bool = true {
		didSet {
			if isActive != oldValue {
				database.setBool(isActive, for: accountID, column: .isActive)
			}
		}
	}

	var username: String? {
		didSet {
			if username != oldValue {
				database.setString(username, for: accountID, column: .username)
			}
		}
	}

	func conditionalGetInfo(for endpoint: String) -> HTTPConditionalGetInfo? {
		database.conditionalGetInfo(for: accountID, endpoint: endpoint)
	}

	func setConditionalGetInfo(_ info: HTTPConditionalGetInfo?, for endpoint: String) {
		database.setConditionalGetInfo(info, for: accountID, endpoint: endpoint)
	}

	var lastArticleFetchStartTime: Date? {
		didSet {
			if lastArticleFetchStartTime != oldValue {
				database.setDate(lastArticleFetchStartTime, for: accountID, column: .lastArticleFetchStartTime)
			}
		}
	}

	var lastArticleFetchEndTime: Date? {
		didSet {
			if lastArticleFetchEndTime != oldValue {
				database.setDate(lastArticleFetchEndTime, for: accountID, column: .lastArticleFetchEndTime)
			}
		}
	}

	var endpointURL: URL? {
		didSet {
			if endpointURL != oldValue {
				database.setString(endpointURL?.absoluteString, for: accountID, column: .endpointURL)
			}
		}
	}

	var externalID: String? {
		didSet {
			if externalID != oldValue {
				database.setString(externalID, for: accountID, column: .externalID)
			}
		}
	}

	init(accountID: String, dataFolder: String, database: AccountSettingsDatabase) {
		self.accountID = accountID
		self.database = database

		AccountSettingsImporter.importIfNeeded(accountID: accountID, dataFolder: dataFolder, database: database)
		database.ensureAccountExists(accountID)

		if let row = database.row(for: accountID) {
			self.name = row.name
			self.isActive = row.isActive
			self.username = row.username
			self.lastArticleFetchStartTime = row.lastArticleFetchStartTime
			self.lastArticleFetchEndTime = row.lastArticleFetchEndTime
			self.endpointURL = row.endpointURL
			self.externalID = row.externalID
		}
	}
}
