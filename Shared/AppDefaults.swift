//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/22/26.
//

import Foundation

/// Settings common to Mac and iOS. Platform-specific settings are in extensions in Mac/AppDefaults.swift and iOS/AppDefaults.swift.
enum AppDefaults {

	static let defaultThemeName = "Default"

	struct Key {
		static let firstRunDate = "firstRunDate"
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let timelineSortDirection = "timelineSortDirection"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let addFeedAccountID = "addFeedAccountID"
		static let addFeedFolderName = "addFeedFolderName"
		static let addFolderAccountID = "addFolderAccountID"
		static let currentThemeName = "currentThemeName"
		static let articleContentJavascriptEnabled = "articleContentJavascriptEnabled"
		static let unreadCountDisplay = "unreadCountDisplay"
	}

	/// Registered by both platforms. Each platform’s registerDefaults adds its own.
	static let commonRegisteredDefaults: [String: Any] = [
		Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
		Key.timelineGroupByFeed: false,
		Key.currentThemeName: defaultThemeName,
		Key.articleContentJavascriptEnabled: true
	]

	static let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()

	static let isFirstRun: Bool = {
		if UserDefaults.standard.object(forKey: Key.firstRunDate) is Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()

	static var lastImageCacheFlushDate: Date? {
		get {
			return date(for: Key.lastImageCacheFlushDate)
		}
		set {
			setDate(for: Key.lastImageCacheFlushDate, newValue)
		}
	}

	static var addFeedAccountID: String? {
		get {
			return string(for: Key.addFeedAccountID)
		}
		set {
			setString(for: Key.addFeedAccountID, newValue)
		}
	}

	static var addFeedFolderName: String? {
		get {
			return string(for: Key.addFeedFolderName)
		}
		set {
			setString(for: Key.addFeedFolderName, newValue)
		}
	}

	static var addFolderAccountID: String? {
		get {
			return string(for: Key.addFolderAccountID)
		}
		set {
			setString(for: Key.addFolderAccountID, newValue)
		}
	}

	static var currentThemeName: String? {
		get {
			return string(for: Key.currentThemeName)
		}
		set {
			setString(for: Key.currentThemeName, newValue)
		}
	}

	static var isArticleContentJavascriptEnabled: Bool {
		get {
			return bool(for: Key.articleContentJavascriptEnabled)
		}
		set {
			setBool(for: Key.articleContentJavascriptEnabled, newValue)
		}
	}

	static var unreadCountDisplay: UnreadCountDisplay {
		get {
			UnreadCountDisplay(rawValue: int(for: Key.unreadCountDisplay)) ?? .count
		}
		set {
			setInt(for: Key.unreadCountDisplay, newValue.rawValue)
			NotificationCenter.default.post(name: .unreadCountDisplaySettingDidChange, object: self)
		}
	}
}

// MARK: - Helpers

extension AppDefaults {

	static func string(for key: String) -> String? {
		return UserDefaults.standard.string(forKey: key)
	}

	static func setString(for key: String, _ value: String?) {
		UserDefaults.standard.set(value, forKey: key)
	}

	static func bool(for key: String) -> Bool {
		return UserDefaults.standard.bool(forKey: key)
	}

	static func setBool(for key: String, _ flag: Bool) {
		UserDefaults.standard.set(flag, forKey: key)
	}

	static func int(for key: String) -> Int {
		return UserDefaults.standard.integer(forKey: key)
	}

	static func setInt(for key: String, _ x: Int) {
		UserDefaults.standard.set(x, forKey: key)
	}

	static func date(for key: String) -> Date? {
		return UserDefaults.standard.object(forKey: key) as? Date
	}

	static func setDate(for key: String, _ date: Date?) {
		UserDefaults.standard.set(date, forKey: key)
	}

	static func sortDirection(for key: String) -> ComparisonResult {
		let rawInt = int(for: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}
}

private extension AppDefaults {

	static var firstRunDate: Date? {
		get {
			return date(for: Key.firstRunDate)
		}
		set {
			setDate(for: Key.firstRunDate, newValue)
		}
	}
}
