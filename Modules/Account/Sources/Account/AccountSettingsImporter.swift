//
//  AccountSettingsImporter.swift
//  Account
//
//  Created by Brent Simmons on 3/6/26.
//

import Foundation
import os
import RSWeb

/// One-time import from a Settings.plist into AccountSettingsDatabase.
@MainActor struct AccountSettingsImporter {
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AccountSettingsImporter")

	static func importIfNeeded(accountID: String, dataFolder: String, database: AccountSettingsDatabase) {
		let plistPath = (dataFolder as NSString).appendingPathComponent("Settings.plist")
		guard FileManager.default.fileExists(atPath: plistPath) else {
			return
		}
		guard !database.accountExists(accountID) else {
			return
		}

		Self.logger.info("AccountSettingsImporter: importing Settings.plist for account \(accountID)")

		guard let data = FileManager.default.contents(atPath: plistPath) else {
			Self.logger.error("AccountSettingsImporter: unable to read Settings.plist for account \(accountID)")
			return
		}

		guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
			Self.logger.error("AccountSettingsImporter: unable to deserialize Settings.plist for account \(accountID)")
			return
		}

		database.ensureAccountExists(accountID)

		if let name = plist["name"] as? String {
			database.setString(name, for: accountID, column: .name)
		}

		if let isActive = plist["isActive"] as? Bool {
			database.setBool(isActive, for: accountID, column: .isActive)
		}

		if let username = plist["username"] as? String {
			database.setString(username, for: accountID, column: .username)
		}

		if let lastArticleFetch = plist["lastArticleFetch"] as? Date {
			database.setDate(lastArticleFetch, for: accountID, column: .lastArticleFetchStartTime)
		}

		if let lastArticleFetchEndTime = plist["lastArticleFetchEndTime"] as? Date {
			database.setDate(lastArticleFetchEndTime, for: accountID, column: .lastRefreshCompletedDate)
		}

		if let endpointURL = plist["endpointURL"] as? String {
			database.setString(endpointURL, for: accountID, column: .endpointURL)
		}

		if let externalID = plist["externalID"] as? String {
			database.setString(externalID, for: accountID, column: .externalID)
		}

		if let conditionalGetDict = plist["conditionalGetInfo"] as? [String: [String: String]] {
			for (endpoint, value) in conditionalGetDict {
				let lastModified = value["lastModified"]
				let etag = value["etag"]
				if let info = HTTPConditionalGetInfo(lastModified: lastModified, etag: etag) {
					database.setConditionalGetInfo(info, for: accountID, endpoint: endpoint)
				}
			}
		}

		Self.logger.info("AccountSettingsImporter: finished importing Settings.plist for account \(accountID)")
	}
}
