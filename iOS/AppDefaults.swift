//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit

struct AppDefaults {

	private static var suiteName: String = {
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		return "\(appIdentifierPrefix)group.\(Bundle.main.bundleIdentifier!)"
	}()
	
	static var shared: UserDefaults {
		return UserDefaults.init(suiteName: suiteName)!
	}
	
	struct Key {
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let firstRunDate = "firstRunDate"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let timelineNumberOfLines = "timelineNumberOfLines"
		static let timelineSortDirection = "timelineSortDirection"
		static let displayUndoAvailableTip = "displayUndoAvailableTip"
		static let refreshInterval = "refreshInterval"
		static let lastRefresh = "lastRefresh"
	}

	static let isFirstRun: Bool = {
		if let _ = AppDefaults.shared.object(forKey: Key.firstRunDate) as? Date {
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

	static var refreshInterval: RefreshInterval {
		get {
			let rawValue = AppDefaults.shared.integer(forKey: Key.refreshInterval)
			return RefreshInterval(rawValue: rawValue) ?? RefreshInterval.everyHour
		}
		set {
			AppDefaults.shared.set(newValue.rawValue, forKey: Key.refreshInterval)
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
	
	static func registerDefaults() {
		let defaults: [String : Any] = [Key.lastImageCacheFlushDate: Date(),
										Key.refreshInterval: RefreshInterval.everyHour.rawValue,
										Key.timelineGroupByFeed: false,
										Key.timelineNumberOfLines: 3,
										Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
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


