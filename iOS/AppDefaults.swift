//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit

struct AppDefaults {

	struct Key {
		static let firstRunDate = "firstRunDate"
		static let timelineSortDirection = "timelineSortDirection"
		static let refreshInterval = "refreshInterval"
		static let lastRefresh = "lastRefresh"
		static let timelineNumberOfLines = "timelineNumberOfLines"
	}

	static let isFirstRun: Bool = {
		if let _ = UserDefaults.standard.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()
	
	static var refreshInterval: RefreshInterval {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: Key.refreshInterval)
			return RefreshInterval(rawValue: rawValue) ?? RefreshInterval.everyHour
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.refreshInterval)
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
		let defaults: [String : Any] = [Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue, Key.refreshInterval: RefreshInterval.everyHour.rawValue, Key.timelineNumberOfLines: 3]
		UserDefaults.standard.register(defaults: defaults)
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


