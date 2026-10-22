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
			AppDefaults.bool(for: Key.openInBrowserInBackground)
		}
		set {
			AppDefaults.setBool(for: Key.openInBrowserInBackground, newValue)
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
			AppDefaults.string(for: Key.importOPMLAccountID)
		}
		set {
			AppDefaults.setString(for: Key.importOPMLAccountID, newValue)
		}
	}

	static var exportOPMLAccountID: String? {
		get {
			AppDefaults.string(for: Key.exportOPMLAccountID)
		}
		set {
			AppDefaults.setString(for: Key.exportOPMLAccountID, newValue)
		}
	}

	static var defaultBrowserID: String? {
		get {
			AppDefaults.string(for: Key.defaultBrowserID)
		}
		set {
			AppDefaults.setString(for: Key.defaultBrowserID, newValue)
		}
	}

	static var showTitleOnMainWindow: Bool {
		AppDefaults.bool(for: Key.showTitleOnMainWindow)
	}

	static var showDebugMenu: Bool {
		AppDefaults.bool(for: Key.showDebugMenu)
	}

	static var feedDoubleClickMarkAsRead: Bool {
		get {
			AppDefaults.bool(for: Key.feedDoubleClickMarkAsRead)
		}
		set {
			AppDefaults.setBool(for: Key.feedDoubleClickMarkAsRead, newValue)
		}
	}

	static var suppressSyncOnLaunch: Bool {
		get {
			AppDefaults.bool(for: Key.suppressSyncOnLaunch)
		}
		set {
			AppDefaults.setBool(for: Key.suppressSyncOnLaunch, newValue)
		}
	}

	static var webInspectorEnabled: Bool {
		get {
			AppDefaults.bool(for: Key.webInspectorEnabled)
		}
		set {
			AppDefaults.setBool(for: Key.webInspectorEnabled, newValue)
		}
	}

	static var webInspectorStartsAttached: Bool {
		get {
			AppDefaults.bool(for: Key.webInspectorStartsAttached)
		}
		set {
			AppDefaults.setBool(for: Key.webInspectorStartsAttached, newValue)
		}
	}

	// Sorting is per window and lives in TimelineWindowState. These two are read-only seeds
	// for a window that has no saved sort, so a setting from before per-window sorting carries over.
	static var timelineSortDirection: ComparisonResult {
		AppDefaults.sortDirection(for: Key.timelineSortDirection)
	}

	static var timelineGroupByFeed: Bool {
		AppDefaults.bool(for: Key.timelineGroupByFeed)
	}

	/// Column layout: multi-column timeline table with the article view below it, like Mail’s View > Use Column Layout. Applies to all windows.
	static var useColumnLayout: Bool {
		get {
			AppDefaults.bool(for: Key.useColumnLayout)
		}
		set {
			AppDefaults.setBool(for: Key.useColumnLayout, newValue)
		}
	}

	/// The main window status bar. Applies to all windows.
	static var showStatusBar: Bool {
		get {
			AppDefaults.bool(for: Key.showStatusBar)
		}
		set {
			AppDefaults.setBool(for: Key.showStatusBar, newValue)
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
			AppDefaults.bool(for: Key.showStatusBarThemeMenu)
		}
		set {
			AppDefaults.setBool(for: Key.showStatusBarThemeMenu, newValue)
		}
	}

	static var statusBarCountMode: StatusBarCountMode {
		get {
			StatusBarCountMode(rawValue: AppDefaults.int(for: Key.statusBarCountMode)) ?? .lastRefresh
		}
		set {
			AppDefaults.setInt(for: Key.statusBarCountMode, newValue.rawValue)
		}
	}

	static var timelineShowsSeparators: Bool {
		AppDefaults.bool(for: Key.timelineShowsSeparators)
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
}
