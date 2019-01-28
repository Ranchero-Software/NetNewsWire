//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit

enum FontSize: Int {
	case small = 0
	case medium = 1
	case large = 2
	case veryLarge = 3
}

enum RefreshInterval: Int {
	case manually = 1
	case every10Minutes = 2
	case every30Minutes = 3
	case everyHour = 4
	case every2Hours = 5
	case every4Hours = 6
	case every8Hours = 7

	func inSeconds() -> TimeInterval {
		switch self {
		case .manually:
			return 0
		case .every10Minutes:
			return 10 * 60
		case .every30Minutes:
			return 30 * 60
		case .everyHour:
			return 60 * 60
		case .every2Hours:
			return 2 * 60 * 60
		case .every4Hours:
			return 4 * 60 * 60
		case .every8Hours:
			return 8 * 60 * 60
		}
	}
}

struct AppDefaults {

	struct Key {
		static let firstRunDate = "firstRunDate"
		static let sidebarFontSize = "sidebarFontSize"
		static let timelineFontSize = "timelineFontSize"
		static let timelineSortDirection = "timelineSortDirection"
		static let detailFontSize = "detailFontSize"
		static let openInBrowserInBackground = "openInBrowserInBackground"
		static let mainWindowWidths = "mainWindowWidths"
		static let refreshInterval = "refreshInterval"

		// Hidden prefs
		static let showTitleOnMainWindow = "KafasisTitleMode"
	}

	private static let smallestFontSizeRawValue = FontSize.small.rawValue
	private static let largestFontSizeRawValue = FontSize.veryLarge.rawValue

	static let isFirstRun: Bool = {
		if let _ = UserDefaults.standard.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()
	
	static var openInBrowserInBackground: Bool {
		get {
			return bool(for: Key.openInBrowserInBackground)
		}
		set {
			setBool(for: Key.openInBrowserInBackground, newValue)
		}
	}

	static var sidebarFontSize: FontSize {
		get {
			return fontSize(for: Key.sidebarFontSize)
		}
		set {
			setFontSize(for: Key.sidebarFontSize, newValue)
		}
	}

	static var timelineFontSize: FontSize {
		get {
			return fontSize(for: Key.timelineFontSize)
		}
		set {
			setFontSize(for: Key.timelineFontSize, newValue)
		}
	}

	static var detailFontSize: FontSize {
		get {
			return fontSize(for: Key.detailFontSize)
		}
		set {
			setFontSize(for: Key.detailFontSize, newValue)
		}
	}

	static var showTitleOnMainWindow: Bool {
		return bool(for: Key.showTitleOnMainWindow)
	}

	static var timelineSortDirection: ComparisonResult {
		get {
			return sortDirection(for: Key.timelineSortDirection)
		}
		set {
			setSortDirection(for: Key.timelineSortDirection, newValue)
		}
	}

	static var mainWindowWidths: [Int]? {
		get {
			return UserDefaults.standard.object(forKey: Key.mainWindowWidths) as? [Int]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.mainWindowWidths)
		}
	}

	static var refreshInterval: RefreshInterval {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: Key.refreshInterval)
			return RefreshInterval(rawValue: rawValue) ?? RefreshInterval.everyHour
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.refreshInterval)
		}
	}

	static func registerDefaults() {
		let defaults: [String : Any] = [Key.sidebarFontSize: FontSize.medium.rawValue, Key.timelineFontSize: FontSize.medium.rawValue, Key.detailFontSize: FontSize.medium.rawValue, Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue, "NSScrollViewShouldScrollUnderTitlebar": false, Key.refreshInterval: RefreshInterval.everyHour.rawValue]

		UserDefaults.standard.register(defaults: defaults)
	}

	static func actualFontSize(for fontSize: FontSize) -> CGFloat {

		switch fontSize {
		case .small:
			return NSFont.systemFontSize
		case .medium:
			return actualFontSize(for: .small) + 1.0
		case .large:
			return actualFontSize(for: .medium) + 4.0
		case .veryLarge:
			return actualFontSize(for: .large) + 8.0
		}
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

	static func fontSize(for key: String) -> FontSize {

		// Punted till after 1.0.
		return .medium

//		var rawFontSize = int(for: key)
//		if rawFontSize < smallestFontSizeRawValue {
//			rawFontSize = smallestFontSizeRawValue
//		}
//		if rawFontSize > largestFontSizeRawValue {
//			rawFontSize = largestFontSizeRawValue
//		}
//		return FontSize(rawValue: rawFontSize)!
	}
	
	static func setFontSize(for key: String, _ fontSize: FontSize) {
		setInt(for: key, fontSize.rawValue)
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


