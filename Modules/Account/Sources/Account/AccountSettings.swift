//
//  AccountSettings.swift
//  Account
//
//  Created by Brent Simmons on 3/3/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb

/// AccountSettings is backed by UserDefaults.
@MainActor final class AccountSettings {

	private enum Key: String {
		case name
		case isActive
		case username
		case conditionalGetInfo
		case lastArticleFetchStartTime
		case lastRefreshCompletedDate
		case endpointURL
		case externalID
		case imported
	}

	private static let lastModifiedKey = "lastModified"
	private static let etagKey = "etag"

	private let accountID: String

	private var plistImported: Bool {
		get {
			UserDefaults.standard.bool(forKey: defaultsKey(.imported))
		}
		set {
			UserDefaults.standard.set(newValue, forKey: defaultsKey(.imported))
		}
	}

	var name: String? {
		get {
			UserDefaults.standard.string(forKey: defaultsKey(.name))
		}
		set {
			UserDefaults.standard.set(newValue, forKey: defaultsKey(.name))
		}
	}

	var isActive: Bool {
		get {
			UserDefaults.standard.bool(forKey: defaultsKey(.isActive))
		}
		set {
			UserDefaults.standard.set(newValue, forKey: defaultsKey(.isActive))
		}
	}

	var username: String? {
		get {
			guard let username = UserDefaults.standard.string(forKey: defaultsKey(.username))?.trimmingWhitespace, !username.isEmpty else {
				return nil
			}
			return username
		}
		set {
			guard let trimmed = newValue?.trimmingWhitespace, !trimmed.isEmpty else {
				return
			}
			UserDefaults.standard.set(trimmed, forKey: defaultsKey(.username))
		}
	}

	func conditionalGetInfo(for endpoint: String) -> HTTPConditionalGetInfo? {
		let key = conditionalGetInfoDefaultsKey(endpoint)
		guard let d = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else {
			return nil
		}
		return HTTPConditionalGetInfo(lastModified: d[Self.lastModifiedKey], etag: d[Self.etagKey])
	}

	func setConditionalGetInfo(_ info: HTTPConditionalGetInfo?, for endpoint: String) {
		let key = conditionalGetInfoDefaultsKey(endpoint)
		if let info {
			var d = [String: String]()
			if let lastModified = info.lastModified {
				d[Self.lastModifiedKey] = lastModified
			}
			if let etag = info.etag {
				d[Self.etagKey] = etag
			}
			UserDefaults.standard.set(d, forKey: key)
		} else {
			UserDefaults.standard.removeObject(forKey: key)
		}
	}

	var lastArticleFetchStartTime: Date? {
		get {
			UserDefaults.standard.object(forKey: defaultsKey(.lastArticleFetchStartTime)) as? Date
		}
		set {
			UserDefaults.standard.set(newValue, forKey: defaultsKey(.lastArticleFetchStartTime))
		}
	}

	var lastRefreshCompletedDate: Date? {
		get {
			UserDefaults.standard.object(forKey: defaultsKey(.lastRefreshCompletedDate)) as? Date
		}
		set {
			UserDefaults.standard.set(newValue, forKey: defaultsKey(.lastRefreshCompletedDate))
		}
	}

	var endpointURL: URL? {
		get {
			guard let urlString = UserDefaults.standard.string(forKey: defaultsKey(.endpointURL))?.trimmingWhitespace, !urlString.isEmpty else {
				return nil
			}
			return URL(string: urlString)
		}
		set {
			guard let trimmed = newValue?.absoluteString.trimmingWhitespace, !trimmed.isEmpty else {
				return
			}
			UserDefaults.standard.set(trimmed, forKey: defaultsKey(.endpointURL))
		}
	}

	var externalID: String? {
		get {
			UserDefaults.standard.string(forKey: defaultsKey(.externalID))
		}
		set {
			UserDefaults.standard.set(newValue, forKey: defaultsKey(.externalID))
		}
	}

	init(accountID: String, dataFolder: String) {
		self.accountID = accountID

		UserDefaults.standard.register(defaults: [defaultsKey(.isActive): true])

		if !self.plistImported {
			if let importedSettings = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: dataFolder) {
				storeImportedSettings(importedSettings)
			}
			self.plistImported = true
		}

		if self.username == nil || self.endpointURL == nil {
			readMissingSettingsFromPlist(accountID: accountID, dataFolder: dataFolder)
		}
		if self.username == nil || self.endpointURL == nil {
			readMissingSettingsFromDatabase()
		}
	}

	func deleteSettings() {
		let defaults = UserDefaults.standard
		let prefix = "\(accountID)-"
		for key in defaults.dictionaryRepresentation().keys {
			if key.hasPrefix(prefix) {
				defaults.removeObject(forKey: key)
			}
		}
	}
}

// MARK: - Private

private extension AccountSettings {

	private func defaultsKey(_ key: Key) -> String {
		"\(accountID)-\(key.rawValue)"
	}

	func conditionalGetInfoDefaultsKey(_ endpoint: String) -> String {
		"\(accountID)-\(Key.conditionalGetInfo.rawValue)-\(endpoint)"
	}

	/// Try to read username and endpointURL from Settings.plist
	/// if they weren't found in UserDefaults.
	func readMissingSettingsFromPlist(accountID: String, dataFolder: String) {
		guard let imported = AccountSettingsImporter.readSettingsFromPlist(accountID: accountID, dataFolder: dataFolder) else {
			return
		}
		if self.username == nil {
			self.username = imported.username
		}
		if self.endpointURL == nil {
			self.endpointURL = imported.endpointURL
		}
	}

	/// Fall back to AccountSettingsDatabase for username and endpointURL
	/// if they weren't found in UserDefaults or Settings.plist.
	func readMissingSettingsFromDatabase() {
		let databasePath = AppConfig.dataFolder.appendingPathComponent("AccountSettings.db").path
		guard let database = AccountSettingsDatabase(databasePath: databasePath) else {
			return
		}

		if self.username == nil {
			self.username = database.username(for: accountID)
		}
		if self.endpointURL == nil, let urlString = database.endpointURL(for: accountID) {
			self.endpointURL = URL(string: urlString)
		}
	}

	func storeImportedSettings(_ imported: AccountSettingsImporter.ImportedSettings) {
		if self.name == nil {
			self.name = imported.name
		}
		if let isActive = imported.isActive {
			self.isActive = isActive
		}
		if self.username == nil {
			self.username = imported.username
		}
		if self.lastArticleFetchStartTime == nil {
			self.lastArticleFetchStartTime = imported.lastArticleFetchStartTime
		}
		if self.lastRefreshCompletedDate == nil {
			self.lastRefreshCompletedDate = imported.lastRefreshCompletedDate
		}
		if self.endpointURL == nil {
			self.endpointURL = imported.endpointURL
		}
		if self.externalID == nil {
			self.externalID = imported.externalID
		}
		if let conditionalGetInfo = imported.conditionalGetInfo {
			for (endpoint, info) in conditionalGetInfo {
				if self.conditionalGetInfo(for: endpoint) == nil {
					setConditionalGetInfo(info, for: endpoint)
				}
			}
		}
	}
}
