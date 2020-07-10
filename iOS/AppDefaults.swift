//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit

enum UserInterfaceColorPalette: Int, CustomStringConvertible, CaseIterable {
	case automatic = 0
	case light = 1
	case dark = 2

	var description: String {
		switch self {
		case .automatic:
			return NSLocalizedString("Automatic", comment: "Automatic")
		case .light:
			return NSLocalizedString("Light", comment: "Light")
		case .dark:
			return NSLocalizedString("Dark", comment: "Dark")
		}
	}
	
}

final class AppDefaults {

	static let shared = AppDefaults()
	private init() {}
	
	static var store: UserDefaults = {
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		let suiteName = "\(appIdentifierPrefix)group.\(Bundle.main.bundleIdentifier!)"
		return UserDefaults.init(suiteName: suiteName)!
	}()
	
	struct Key {
		static let userInterfaceColorPalette = "userInterfaceColorPalette"
		static let activeExtensionPointIDs = "activeExtensionPointIDs"
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let firstRunDate = "firstRunDate"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let refreshClearsReadArticles = "refreshClearsReadArticles"
		static let timelineNumberOfLines = "timelineNumberOfLines"
		static let timelineIconDimension = "timelineIconSize"
		static let timelineSortDirection = "timelineSortDirection"
		static let articleFullscreenAvailable = "articleFullscreenAvailable"
		static let articleFullscreenEnabled = "articleFullscreenEnabled"
		static let confirmMarkAllAsRead = "confirmMarkAllAsRead"
		static let lastRefresh = "lastRefresh"
		static let addWebFeedAccountID = "addWebFeedAccountID"
		static let addWebFeedFolderName = "addWebFeedFolderName"
		static let addFolderAccountID = "addFolderAccountID"
	}

	let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()

	let isFirstRun: Bool = {
		if let _ = AppDefaults.store.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()
	
	static var userInterfaceColorPalette: UserInterfaceColorPalette {
		get {
			if let result = UserInterfaceColorPalette(rawValue: int(for: Key.userInterfaceColorPalette)) {
				return result
			}
			return .automatic
		}
		set {
			setInt(for: Key.userInterfaceColorPalette, newValue.rawValue)
		}
	}

	var addWebFeedAccountID: String? {
		get {
			return AppDefaults.string(for: Key.addWebFeedAccountID)
		}
		set {
			AppDefaults.setString(for: Key.addWebFeedAccountID, newValue)
		}
	}
	
	var addWebFeedFolderName: String? {
		get {
			return AppDefaults.string(for: Key.addWebFeedFolderName)
		}
		set {
			AppDefaults.setString(for: Key.addWebFeedFolderName, newValue)
		}
	}
	
	var addFolderAccountID: String? {
		get {
			return AppDefaults.string(for: Key.addFolderAccountID)
		}
		set {
			AppDefaults.setString(for: Key.addFolderAccountID, newValue)
		}
	}
	
	var activeExtensionPointIDs: [[AnyHashable : AnyHashable]]? {
		get {
			return UserDefaults.standard.object(forKey: Key.activeExtensionPointIDs) as? [[AnyHashable : AnyHashable]]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.activeExtensionPointIDs)
		}
	}
	
	var lastImageCacheFlushDate: Date? {
		get {
			return AppDefaults.date(for: Key.lastImageCacheFlushDate)
		}
		set {
			AppDefaults.setDate(for: Key.lastImageCacheFlushDate, newValue)
		}
	}

	var timelineGroupByFeed: Bool {
		get {
			return AppDefaults.bool(for: Key.timelineGroupByFeed)
		}
		set {
			AppDefaults.setBool(for: Key.timelineGroupByFeed, newValue)
		}
	}

	var refreshClearsReadArticles: Bool {
		get {
			return AppDefaults.bool(for: Key.refreshClearsReadArticles)
		}
		set {
			AppDefaults.setBool(for: Key.refreshClearsReadArticles, newValue)
		}
	}

	var timelineSortDirection: ComparisonResult {
		get {
			return AppDefaults.sortDirection(for: Key.timelineSortDirection)
		}
		set {
			AppDefaults.setSortDirection(for: Key.timelineSortDirection, newValue)
		}
	}

	var articleFullscreenAvailable: Bool {
		get {
			return AppDefaults.bool(for: Key.articleFullscreenAvailable)
		}
		set {
			AppDefaults.setBool(for: Key.articleFullscreenAvailable, newValue)
		}
	}

	var articleFullscreenEnabled: Bool {
		get {
			return AppDefaults.bool(for: Key.articleFullscreenEnabled)
		}
		set {
			AppDefaults.setBool(for: Key.articleFullscreenEnabled, newValue)
		}
	}

	var confirmMarkAllAsRead: Bool {
		get {
			return AppDefaults.bool(for: Key.confirmMarkAllAsRead)
		}
		set {
			AppDefaults.setBool(for: Key.confirmMarkAllAsRead, newValue)
		}
	}
	
	var lastRefresh: Date? {
		get {
			return AppDefaults.date(for: Key.lastRefresh)
		}
		set {
			AppDefaults.setDate(for: Key.lastRefresh, newValue)
		}
	}
	
	var timelineNumberOfLines: Int {
		get {
			return AppDefaults.int(for: Key.timelineNumberOfLines)
		}
		set {
			AppDefaults.setInt(for: Key.timelineNumberOfLines, newValue)
		}
	}
	
	var timelineIconSize: IconSize {
		get {
			let rawValue = AppDefaults.store.integer(forKey: Key.timelineIconDimension)
			return IconSize(rawValue: rawValue) ?? IconSize.medium
		}
		set {
			AppDefaults.store.set(newValue.rawValue, forKey: Key.timelineIconDimension)
		}
	}
	
	static func registerDefaults() {
		let defaults: [String : Any] = [Key.userInterfaceColorPalette: UserInterfaceColorPalette.automatic.rawValue,
										Key.timelineGroupByFeed: false,
										Key.refreshClearsReadArticles: false,
										Key.timelineNumberOfLines: 2,
										Key.timelineIconDimension: IconSize.medium.rawValue,
										Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
										Key.articleFullscreenAvailable: false,
										Key.articleFullscreenEnabled: false,
										Key.confirmMarkAllAsRead: true]
		AppDefaults.store.register(defaults: defaults)
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

	static func string(for key: String) -> String? {
		return UserDefaults.standard.string(forKey: key)
	}
	
	static func setString(for key: String, _ value: String?) {
		UserDefaults.standard.set(value, forKey: key)
	}

	static func bool(for key: String) -> Bool {
		return AppDefaults.store.bool(forKey: key)
	}

	static func setBool(for key: String, _ flag: Bool) {
		AppDefaults.store.set(flag, forKey: key)
	}

	static func int(for key: String) -> Int {
		return AppDefaults.store.integer(forKey: key)
	}
	
	static func setInt(for key: String, _ x: Int) {
		AppDefaults.store.set(x, forKey: key)
	}
	
	static func date(for key: String) -> Date? {
		return AppDefaults.store.object(forKey: key) as? Date
	}

	static func setDate(for key: String, _ date: Date?) {
		AppDefaults.store.set(date, forKey: key)
	}

	static func sortDirection(for key:String) -> ComparisonResult {
		let rawInt = int(for: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}

	static func setSortDirection(for key: String, _ value: ComparisonResult) {
		if value == .orderedAscending {
			setInt(for: key, ComparisonResult.orderedAscending.rawValue)
		}
		else {
			setInt(for: key, ComparisonResult.orderedDescending.rawValue)
		}
	}
	
}
