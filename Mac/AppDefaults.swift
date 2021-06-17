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

final class AppDefaults {
	
	static var shared = AppDefaults()
	private init() {}

	struct Key {
		static let firstRunDate = "firstRunDate"
		static let windowState = "windowState"
		static let activeExtensionPointIDs = "activeExtensionPointIDs"
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let sidebarFontSize = "sidebarFontSize"
		static let timelineFontSize = "timelineFontSize"
		static let timelineSortDirection = "timelineSortDirection"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let detailFontSize = "detailFontSize"
		static let openInBrowserInBackground = "openInBrowserInBackground"
		static let articleTextSize = "articleTextSize"
		static let refreshInterval = "refreshInterval"
		static let addWebFeedAccountID = "addWebFeedAccountID"
		static let addWebFeedFolderName = "addWebFeedFolderName"
		static let addFolderAccountID = "addFolderAccountID"
		static let importOPMLAccountID = "importOPMLAccountID"
		static let exportOPMLAccountID = "exportOPMLAccountID"
		static let defaultBrowserID = "defaultBrowserID"

		// Hidden prefs
		static let showDebugMenu = "ShowDebugMenu"
		static let timelineShowsSeparators = "CorreiaSeparators"
		static let showTitleOnMainWindow = "KafasisTitleMode"
		static let feedDoubleClickMarkAsRead = "GruberFeedDoubleClickMarkAsRead"
		static let suppressSyncOnLaunch = "DevroeSuppressSyncOnLaunch"

		#if !MAC_APP_STORE
			static let webInspectorEnabled = "WebInspectorEnabled"
			static let webInspectorStartsAttached = "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached"
		#endif
	}

	private static let smallestFontSizeRawValue = FontSize.small.rawValue
	private static let largestFontSizeRawValue = FontSize.veryLarge.rawValue

	let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()
	
	var isFirstRun: Bool = {
		if let _ = UserDefaults.standard.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()
	
	var windowState: [AnyHashable : Any]? {
		get {
			return UserDefaults.standard.object(forKey: Key.windowState) as? [AnyHashable : Any]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.windowState)
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
	
	var openInBrowserInBackground: Bool {
		get {
			return AppDefaults.bool(for: Key.openInBrowserInBackground)
		}
		set {
			AppDefaults.setBool(for: Key.openInBrowserInBackground, newValue)
		}
	}

	var sidebarFontSize: FontSize {
		get {
			return fontSize(for: Key.sidebarFontSize)
		}
		set {
			AppDefaults.setFontSize(for: Key.sidebarFontSize, newValue)
		}
	}

	var timelineFontSize: FontSize {
		get {
			return fontSize(for: Key.timelineFontSize)
		}
		set {
			AppDefaults.setFontSize(for: Key.timelineFontSize, newValue)
		}
	}

	var detailFontSize: FontSize {
		get {
			return fontSize(for: Key.detailFontSize)
		}
		set {
			AppDefaults.setFontSize(for: Key.detailFontSize, newValue)
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
	
	var importOPMLAccountID: String? {
		get {
			return AppDefaults.string(for: Key.importOPMLAccountID)
		}
		set {
			AppDefaults.setString(for: Key.importOPMLAccountID, newValue)
		}
	}
	
	var exportOPMLAccountID: String? {
		get {
			return AppDefaults.string(for: Key.exportOPMLAccountID)
		}
		set {
			AppDefaults.setString(for: Key.exportOPMLAccountID, newValue)
		}
	}

	var defaultBrowserID: String? {
		get {
			return AppDefaults.string(for: Key.defaultBrowserID)
		}
		set {
			AppDefaults.setString(for: Key.defaultBrowserID, newValue)
		}
	}
	
	var showTitleOnMainWindow: Bool {
		return AppDefaults.bool(for: Key.showTitleOnMainWindow)
	}

	var showDebugMenu: Bool {
		return AppDefaults.bool(for: Key.showDebugMenu)
 	}

	var feedDoubleClickMarkAsRead: Bool {
		get {
			return AppDefaults.bool(for: Key.feedDoubleClickMarkAsRead)
		}
		set {
			AppDefaults.setBool(for: Key.feedDoubleClickMarkAsRead, newValue)
		}
	}

	var suppressSyncOnLaunch: Bool {
		get {
			return AppDefaults.bool(for: Key.suppressSyncOnLaunch)
		}
		set {
			AppDefaults.setBool(for: Key.suppressSyncOnLaunch, newValue)
		}
	}

	#if !MAC_APP_STORE
		var webInspectorEnabled: Bool {
			get {
				return AppDefaults.bool(for: Key.webInspectorEnabled)
			}
			set {
				AppDefaults.setBool(for: Key.webInspectorEnabled, newValue)
			}
		}

		var webInspectorStartsAttached: Bool {
			get {
				return AppDefaults.bool(for: Key.webInspectorStartsAttached)
			}
			set {
				AppDefaults.setBool(for: Key.webInspectorStartsAttached, newValue)
			}
		}
	#endif

	var timelineSortDirection: ComparisonResult {
		get {
			return AppDefaults.sortDirection(for: Key.timelineSortDirection)
		}
		set {
			AppDefaults.setSortDirection(for: Key.timelineSortDirection, newValue)
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
	
	var timelineShowsSeparators: Bool {
		return AppDefaults.bool(for: Key.timelineShowsSeparators)
	}

	var articleTextSize: ArticleTextSize {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: Key.articleTextSize)
			return ArticleTextSize(rawValue: rawValue) ?? ArticleTextSize.large
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.articleTextSize)
		}
	}

	var refreshInterval: RefreshInterval {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: Key.refreshInterval)
			return RefreshInterval(rawValue: rawValue) ?? RefreshInterval.everyHour
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.refreshInterval)
		}
	}

	func registerDefaults() {
		#if DEBUG
 		let showDebugMenu = true
 		#else
 		let showDebugMenu = false
 		#endif

		let defaults: [String : Any] = [Key.sidebarFontSize: FontSize.medium.rawValue,
										Key.timelineFontSize: FontSize.medium.rawValue,
										Key.detailFontSize: FontSize.medium.rawValue,
										Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
										Key.timelineGroupByFeed: false,
										"NSScrollViewShouldScrollUnderTitlebar": false,
										Key.refreshInterval: RefreshInterval.everyHour.rawValue,
										Key.showDebugMenu: showDebugMenu]

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

	func actualFontSize(for fontSize: FontSize) -> CGFloat {
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
			return AppDefaults.date(for: Key.firstRunDate)
		}
		set {
			AppDefaults.setDate(for: Key.firstRunDate, newValue)
		}
	}

	func fontSize(for key: String) -> FontSize {
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
