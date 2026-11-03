//
//  AppDefaults+Mac.swift
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

/// What the status bar’s count text shows. Clicking the text cycles through them.
enum StatusBarCountMode: Int {
	case unreadCount = 0
	case foldersAndFeeds = 1
	case lastRefresh = 2

	/// The mode after this one when clicking. Skips the unread count when unread counts are hidden.
	func next(includingUnreadCount: Bool) -> StatusBarCountMode {
		switch self {
		case .lastRefresh:
			includingUnreadCount ? .unreadCount : .foldersAndFeeds
		case .unreadCount:
			.foldersAndFeeds
		case .foldersAndFeeds:
			.lastRefresh
		}
	}
}

extension AppDefaults.Key {
	static let legacyWindowState = "windowState"
	static let secureWindowState = "secureWindowState"
	static let sidebarFontSize = "sidebarFontSize"
	static let timelineFontSize = "timelineFontSize"
	static let useColumnLayout = "useColumnLayout"
	static let showStatusBar = "showStatusBar"
	static let showStatusBarThemeMenu = "showStatusBarThemeMenu"
	static let statusBarCountMode = "statusBarCountMode"
	static let detailFontSize = "detailFontSize"
	static let openInBrowserInBackground = "openInBrowserInBackground"
	static let subscribeToFeedsInDefaultBrowser = "subscribeToFeedsInDefaultBrowser"
	static let articleTextSize = "articleTextSize"
	static let refreshInterval = "refreshInterval"
	static let importOPMLAccountID = "importOPMLAccountID"
	static let exportOPMLAccountID = "exportOPMLAccountID"
	static let defaultBrowserID = "defaultBrowserID"

	// Hidden prefs
	static let showDebugMenu = "ShowDebugMenu"
	static let timelineShowsSeparators = "CorreiaSeparators"
	static let showTitleOnMainWindow = "KafasisTitleMode"
	static let feedDoubleClickMarkAsRead = "GruberFeedDoubleClickMarkAsRead"
	static let suppressSyncOnLaunch = "DevroeSuppressSyncOnLaunch"
	static let webInspectorEnabled = "WebInspectorEnabled"
	static let webInspectorStartsAttached = "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached"
}

extension AppDefaults {

	private static let smallestFontSizeRawValue = FontSize.small.rawValue
	private static let largestFontSizeRawValue = FontSize.veryLarge.rawValue

	/// Stores window state prior to switching to secure state restoration.
	///
	/// This is referenced temporarily, only to be able to provide migration from legacy to secure window state.
	/// TODO: delete for NetNewsWire 7.
	static var legacyWindowState: [AnyHashable: Any]? {
		UserDefaults.standard.object(forKey: Key.legacyWindowState) as? [AnyHashable: Any]
	}

	static func deleteLegacyWindowState() {
		UserDefaults.standard.removeObject(forKey: Key.legacyWindowState)
	}

	static var secureWindowState: Data? {
		get {
			UserDefaults.standard.object(forKey: Key.secureWindowState) as? Data
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.secureWindowState)
		}
	}

	static var openInBrowserInBackground: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.openInBrowserInBackground)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.openInBrowserInBackground)
		}
	}

	// Special case for this default: store/retrieve it from the shared app group
	// defaults, so that it can be resolved by the Safari App Extension.
	static var subscribeToFeedDefaults: UserDefaults {
		if let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String,
		   let appGroupDefaults = UserDefaults(suiteName: appGroupID) {
			appGroupDefaults
		} else {
			UserDefaults.standard
		}
	}

	static var subscribeToFeedsInDefaultBrowser: Bool {
		get {
			subscribeToFeedDefaults.bool(forKey: Key.subscribeToFeedsInDefaultBrowser)
		}
		set {
			subscribeToFeedDefaults.set(newValue, forKey: Key.subscribeToFeedsInDefaultBrowser)
		}
	}

	static var sidebarFontSize: FontSize {
		get {
			fontSize(for: Key.sidebarFontSize)
		}
		set {
			AppDefaults.setFontSize(for: Key.sidebarFontSize, newValue)
		}
	}

	static var timelineFontSize: FontSize {
		get {
			fontSize(for: Key.timelineFontSize)
		}
		set {
			AppDefaults.setFontSize(for: Key.timelineFontSize, newValue)
		}
	}

	static var detailFontSize: FontSize {
		get {
			fontSize(for: Key.detailFontSize)
		}
		set {
			AppDefaults.setFontSize(for: Key.detailFontSize, newValue)
		}
	}

	static var importOPMLAccountID: String? {
		get {
			UserDefaults.standard.string(forKey: Key.importOPMLAccountID)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.importOPMLAccountID)
		}
	}

	static var exportOPMLAccountID: String? {
		get {
			UserDefaults.standard.string(forKey: Key.exportOPMLAccountID)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.exportOPMLAccountID)
		}
	}

	static var defaultBrowserID: String? {
		get {
			UserDefaults.standard.string(forKey: Key.defaultBrowserID)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.defaultBrowserID)
		}
	}

	static var showTitleOnMainWindow: Bool {
		UserDefaults.standard.bool(forKey: Key.showTitleOnMainWindow)
	}

	static var showDebugMenu: Bool {
		UserDefaults.standard.bool(forKey: Key.showDebugMenu)
	}

	static var feedDoubleClickMarkAsRead: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.feedDoubleClickMarkAsRead)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.feedDoubleClickMarkAsRead)
		}
	}

	static var suppressSyncOnLaunch: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.suppressSyncOnLaunch)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.suppressSyncOnLaunch)
		}
	}

	static var webInspectorEnabled: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.webInspectorEnabled)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.webInspectorEnabled)
		}
	}

	static var webInspectorStartsAttached: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.webInspectorStartsAttached)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.webInspectorStartsAttached)
		}
	}

	// Sorting is per window and lives in TimelineWindowState. These two are read-only seeds
	// for a window that has no saved sort, so a setting from before per-window sorting carries over.
	static var timelineSortDirection: ComparisonResult {
		AppDefaults.sortDirection(for: Key.timelineSortDirection)
	}

	static var timelineGroupByFeed: Bool {
		UserDefaults.standard.bool(forKey: Key.timelineGroupByFeed)
	}

	/// Column layout: multi-column timeline table with the article view below it, like Mail’s View > Use Column Layout. Applies to all windows.
	static var useColumnLayout: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.useColumnLayout)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.useColumnLayout)
		}
	}

	/// The main window status bar. Applies to all windows.
	static var showStatusBar: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.showStatusBar)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.showStatusBar)
		}
	}

	/// The status bar is off by default on macOS 26 and on by default everywhere else.
	private static var showStatusBarDefault: Bool {
		if #available(macOS 27.0, *) {
			return true
		}
		if #available(macOS 26.0, *) {
			return false
		}
		return true
	}

	static var showStatusBarThemeMenu: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.showStatusBarThemeMenu)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.showStatusBarThemeMenu)
		}
	}

	static var statusBarCountMode: StatusBarCountMode {
		get {
			StatusBarCountMode(rawValue: UserDefaults.standard.integer(forKey: Key.statusBarCountMode)) ?? .lastRefresh
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.statusBarCountMode)
		}
	}

	static var timelineShowsSeparators: Bool {
		UserDefaults.standard.bool(forKey: Key.timelineShowsSeparators)
	}

	static var articleTextSize: ArticleTextSize {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: Key.articleTextSize)
			return ArticleTextSize(rawValue: rawValue) ?? ArticleTextSize.large
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.articleTextSize)
		}
	}

	static var refreshInterval: RefreshInterval {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: Key.refreshInterval)
			if rawValue == 2 { // Old every-10-minutes setting — now using 30 minutes as minimum.
				return .every30Minutes
			}
			return RefreshInterval(rawValue: rawValue) ?? .every2Hours
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.refreshInterval)
		}
	}

	@MainActor static func registerDefaults() {
		// Migrate every-10-minute refresh interval to 30 minutes.
		let rawValue = UserDefaults.standard.integer(forKey: Key.refreshInterval)
		if rawValue == 2 {
			UserDefaults.standard.set(RefreshInterval.every30Minutes.rawValue, forKey: Key.refreshInterval)
		}

		#if DEBUG
 		let showDebugMenu = true
 		#else
 		let showDebugMenu = false
 		#endif

		let platformDefaults: [String: Any] = [
			Key.sidebarFontSize: FontSize.medium.rawValue,
			Key.timelineFontSize: FontSize.medium.rawValue,
			Key.detailFontSize: FontSize.medium.rawValue,
			Key.useColumnLayout: false,
			Key.showStatusBar: Self.showStatusBarDefault,
			Key.showStatusBarThemeMenu: true,
			Key.statusBarCountMode: StatusBarCountMode.lastRefresh.rawValue,
			"NSScrollViewShouldScrollUnderTitlebar": false,
			Key.refreshInterval: RefreshInterval.every2Hours.rawValue,
			Key.showDebugMenu: showDebugMenu
		]

		let defaults = commonRegisteredDefaults.merging(platformDefaults) { _, platformValue in platformValue }
		UserDefaults.standard.register(defaults: defaults)
	}

	static func actualFontSize(for fontSize: FontSize) -> CGFloat {
		switch fontSize {
		case .small:
			NSFont.systemFontSize
		case .medium:
			actualFontSize(for: .small) + 1.0
		case .large:
			actualFontSize(for: .medium) + 4.0
		case .veryLarge:
			actualFontSize(for: .large) + 8.0
		}
	}
}

private extension AppDefaults {

	static func fontSize(for key: String) -> FontSize {
		// Punted till after 1.0.
		.medium

//		var rawFontSize = UserDefaults.standard.integer(forKey: key)
//		if rawFontSize < smallestFontSizeRawValue {
//			rawFontSize = smallestFontSizeRawValue
//		}
//		if rawFontSize > largestFontSizeRawValue {
//			rawFontSize = largestFontSizeRawValue
//		}
//		return FontSize(rawValue: rawFontSize)!
	}

	static func setFontSize(for key: String, _ fontSize: FontSize) {
		UserDefaults.standard.set(fontSize.rawValue, forKey: key)
	}
}
