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

struct AppDefaults {

	struct Key {
		static let firstRunDate = "firstRunDate"
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let sidebarFontSize = "sidebarFontSize"
		static let timelineFontSize = "timelineFontSize"
		static let timelineSortDirection = "timelineSortDirection"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let detailFontSize = "detailFontSize"
		static let openInBrowserInBackground = "openInBrowserInBackground"
		static let mainWindowWidths = "mainWindowWidths"
		static let refreshInterval = "refreshInterval"
		static let addFeedAccountID = "addFeedAccountID"
		static let addFolderAccountID = "addFolderAccountID"
		static let importOPMLAccountID = "importOPMLAccountID"
		static let exportOPMLAccountID = "exportOPMLAccountID"

		// Hidden prefs
		static let timelineShowsSeparators = "CorreiaSeparators"
		static let showTitleOnMainWindow = "KafasisTitleMode"
		static let hideDockUnreadCount = "JustinMillerHideDockUnreadCount"

		static let webInspectorEnabled = "WebInspectorEnabled"
		static let webInspectorStartsAttached = "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached"
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
	
	static var lastImageCacheFlushDate: Date? {
		get {
			return date(for: Key.lastImageCacheFlushDate)
		}
		set {
			setDate(for: Key.lastImageCacheFlushDate, newValue)
		}
	}
	
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

	static var addFeedAccountID: String? {
		get {
			return string(for: Key.addFeedAccountID)
		}
		set {
			setString(for: Key.addFeedAccountID, newValue)
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
	
	static var importOPMLAccountID: String? {
		get {
			return string(for: Key.importOPMLAccountID)
		}
		set {
			setString(for: Key.importOPMLAccountID, newValue)
		}
	}
	
	static var exportOPMLAccountID: String? {
		get {
			return string(for: Key.exportOPMLAccountID)
		}
		set {
			setString(for: Key.exportOPMLAccountID, newValue)
		}
	}
	
	static var showTitleOnMainWindow: Bool {
		return bool(for: Key.showTitleOnMainWindow)
	}

	static var hideDockUnreadCount: Bool {
		return bool(for: Key.hideDockUnreadCount)
	}

	static var webInspectorEnabled: Bool {
		get {
			return bool(for: Key.webInspectorEnabled)
		}
		set {
			setBool(for: Key.webInspectorEnabled, newValue)
		}
	}

	static var webInspectorStartsAttached: Bool {
		get {
			return bool(for: Key.webInspectorStartsAttached)
		}
		set {
			setBool(for: Key.webInspectorStartsAttached, newValue)
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
	
	static var timelineGroupByFeed: Bool {
		get {
			return bool(for: Key.timelineGroupByFeed)
		}
		set {
			setBool(for: Key.timelineGroupByFeed, newValue)
		}
	}
	
	static var timelineShowsSeparators: Bool {
		return bool(for: Key.timelineShowsSeparators)
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
		let defaults: [String : Any] = [Key.lastImageCacheFlushDate: Date(),
										Key.sidebarFontSize: FontSize.medium.rawValue,
										Key.timelineFontSize: FontSize.medium.rawValue,
										Key.detailFontSize: FontSize.medium.rawValue,
										Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
										Key.timelineGroupByFeed: false,
										"NSScrollViewShouldScrollUnderTitlebar": false,
										Key.refreshInterval: RefreshInterval.everyHour.rawValue]

		UserDefaults.standard.register(defaults: defaults)

		// It seems that registering a default for NSQuitAlwaysKeepsWindows to true
		// is not good enough to get the system to respect it, so we have to literally
		// set it as the default to get it to take effect. This overrides a system-wide
		// setting in the System Preferences, which is ostensibly meant to "close windows"
		// in an app, but has the side-effect of also not preserving or restoring any state
		// for the window. Since we've switched to using the standard state preservation and
		// restoration mechanisms, and because it seems highly unlikely any user would object
		// to NetNewsWire preserving this state, we'll force the preference on. If this becomes
		// an issue, this could be changed to proactively look for whether the default has been
		// set _by the user_ to false, and respect that default if it is so-set.
//		UserDefaults.standard.set(true, forKey: "NSQuitAlwaysKeepsWindows")

		// TODO: revisit the above when coming back to state restoration issues.
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

// MARK: -

extension UserDefaults {
	/// This property exists so that it can conveniently be observed via KVO
	@objc var CorreiaSeparators: Bool {
		get {
			return bool(forKey: AppDefaults.Key.timelineShowsSeparators)
		}
		set {
			set(newValue, forKey: AppDefaults.Key.timelineShowsSeparators)
		}
	}
}

