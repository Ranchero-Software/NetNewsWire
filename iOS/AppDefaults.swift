//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit

struct AppDefaults {

	static var shared: UserDefaults = {
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		let suiteName = "\(appIdentifierPrefix)group.\(Bundle.main.bundleIdentifier!)"
		return UserDefaults.init(suiteName: suiteName)!
	}()
	
	struct Key {
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let firstRunDate = "firstRunDate"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let timelineNumberOfLines = "timelineNumberOfLines"
		static let timelineIconSize = "timelineIconSize"
		static let timelineSortDirection = "timelineSortDirection"
		static let articleFullscreenEnabled = "articleFullscreenEnabled"
		static let displayUndoAvailableTip = "displayUndoAvailableTip"
		static let lastRefresh = "lastRefresh"
		static let addWebFeedAccountID = "addWebFeedAccountID"
		static let addWebFeedFolderName = "addWebFeedFolderName"
		static let addFolderAccountID = "addFolderAccountID"
	}

	static let isFirstRun: Bool = {
		if let _ = AppDefaults.shared.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()

	static var addWebFeedAccountID: String? {
		get {
			return string(for: Key.addWebFeedAccountID)
		}
		set {
			setString(for: Key.addWebFeedAccountID, newValue)
		}
	}
	
	static var addWebFeedFolderName: String? {
		get {
			return string(for: Key.addWebFeedFolderName)
		}
		set {
			setString(for: Key.addWebFeedFolderName, newValue)
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
	
	static var lastImageCacheFlushDate: Date? {
		get {
			return date(for: Key.lastImageCacheFlushDate)
		}
		set {
			setDate(for: Key.lastImageCacheFlushDate, newValue)
		}
	}

	static var timelineGroupByFeed: Bool {
		get {
			return bool(for: Key.timelineGroupByFeed)
		}
		set {
			setBool(for: Key.timelineGroupByFeed, newValue)
		}
	}

	static var timelineSortDirection: ComparisonResult {
		get {
			return sortDirection(for: Key.timelineSortDirection)
		}
		set {
			setSortDirection(for: Key.timelineSortDirection, newValue)
		}
	}

	static var articleFullscreenEnabled: Bool {
		get {
			return bool(for: Key.articleFullscreenEnabled)
		}
		set {
			setBool(for: Key.articleFullscreenEnabled, newValue)
		}
	}

	static var displayUndoAvailableTip: Bool {
		get {
			return bool(for: Key.displayUndoAvailableTip)
		}
		set {
			setBool(for: Key.displayUndoAvailableTip, newValue)
		}
	}
	
	static var lastRefresh: Date? {
		get {
			return date(for: Key.lastRefresh)
		}
		set {
			setDate(for: Key.lastRefresh, newValue)
		}
	}
	
	static var timelineNumberOfLines: Int {
		get {
			return int(for: Key.timelineNumberOfLines)
		}
		set {
			setInt(for: Key.timelineNumberOfLines, newValue)
		}
	}
	
	static var timelineIconSize: IconSize {
		get {
			let rawValue = AppDefaults.shared.integer(forKey: Key.timelineIconSize)
			return IconSize(rawValue: rawValue) ?? IconSize.medium
		}
		set {
			AppDefaults.shared.set(newValue.rawValue, forKey: Key.timelineIconSize)
		}
	}
	
	static func registerDefaults() {
		let defaults: [String : Any] = [Key.lastImageCacheFlushDate: Date(),
										Key.timelineGroupByFeed: false,
										Key.timelineNumberOfLines: 2,
										Key.timelineIconSize: IconSize.medium.rawValue,
										Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
										Key.articleFullscreenEnabled: false,
										Key.displayUndoAvailableTip: true]
		AppDefaults.shared.register(defaults: defaults)
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
		return AppDefaults.shared.bool(forKey: key)
	}

	static func setBool(for key: String, _ flag: Bool) {
		AppDefaults.shared.set(flag, forKey: key)
	}

	static func int(for key: String) -> Int {
		return AppDefaults.shared.integer(forKey: key)
	}
	
	static func setInt(for key: String, _ x: Int) {
		AppDefaults.shared.set(x, forKey: key)
	}
	
	static func date(for key: String) -> Date? {
		return AppDefaults.shared.object(forKey: key) as? Date
	}

	static func setDate(for key: String, _ date: Date?) {
		AppDefaults.shared.set(date, forKey: key)
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
