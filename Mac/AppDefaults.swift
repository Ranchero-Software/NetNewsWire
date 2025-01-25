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

	static let defaultThemeName = "Default"

	static let shared = AppDefaults()

	private static let smallestFontSizeRawValue = FontSize.small.rawValue
	private static let largestFontSizeRawValue = FontSize.veryLarge.rawValue

	let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()

	var isFirstRun: Bool = {
		if UserDefaults.standard.object(forKey: AppDefaultsKey.firstRunDate) as? Date == nil {
			firstRunDate = Date()
			return true
		}
		return true
	}()

	var windowState: [AnyHashable: Any]? {
		get {
			return UserDefaults.standard.object(forKey: AppDefaultsKey.windowState) as? [AnyHashable: Any]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: AppDefaultsKey.windowState)
		}
	}

	var lastImageCacheFlushDate: Date? {
		get {
			return AppDefaults.date(for: AppDefaultsKey.lastImageCacheFlushDate)
		}
		set {
			AppDefaults.setDate(for: AppDefaultsKey.lastImageCacheFlushDate, newValue)
		}
	}

	var openInBrowserInBackground: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.openInBrowserInBackground)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.openInBrowserInBackground, newValue)
		}
	}

	// Special case for this default: store/retrieve it from the shared app group
	// defaults, so that it can be resolved by the Safari App Extension.
	var subscribeToFeedDefaults: UserDefaults {
		if let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String,
		   let appGroupDefaults = UserDefaults(suiteName: appGroupID) {
			return appGroupDefaults
		} else {
			return UserDefaults.standard
		}
	}

	var subscribeToFeedsInDefaultBrowser: Bool {
		get {
			return subscribeToFeedDefaults.bool(forKey: AppDefaultsKey.subscribeToFeedsInDefaultBrowser)
		}
		set {
			subscribeToFeedDefaults.set(newValue, forKey: AppDefaultsKey.subscribeToFeedsInDefaultBrowser)
		}
	}

	var sidebarFontSize: FontSize {
		get {
			return fontSize(for: AppDefaultsKey.sidebarFontSize)
		}
		set {
			AppDefaults.setFontSize(for: AppDefaultsKey.sidebarFontSize, newValue)
		}
	}

	var timelineFontSize: FontSize {
		get {
			return fontSize(for: AppDefaultsKey.timelineFontSize)
		}
		set {
			AppDefaults.setFontSize(for: AppDefaultsKey.timelineFontSize, newValue)
		}
	}

	var detailFontSize: FontSize {
		get {
			return fontSize(for: AppDefaultsKey.detailFontSize)
		}
		set {
			AppDefaults.setFontSize(for: AppDefaultsKey.detailFontSize, newValue)
		}
	}

	var addFeedAccountID: String? {
		get {
			return AppDefaults.string(for: AppDefaultsKey.addFeedAccountID)
		}
		set {
			AppDefaults.setString(for: AppDefaultsKey.addFeedAccountID, newValue)
		}
	}

	var addFeedFolderName: String? {
		get {
			return AppDefaults.string(for: AppDefaultsKey.addFeedFolderName)
		}
		set {
			AppDefaults.setString(for: AppDefaultsKey.addFeedFolderName, newValue)
		}
	}

	var addFolderAccountID: String? {
		get {
			return AppDefaults.string(for: AppDefaultsKey.addFolderAccountID)
		}
		set {
			AppDefaults.setString(for: AppDefaultsKey.addFolderAccountID, newValue)
		}
	}

	var importOPMLAccountID: String? {
		get {
			return AppDefaults.string(for: AppDefaultsKey.importOPMLAccountID)
		}
		set {
			AppDefaults.setString(for: AppDefaultsKey.importOPMLAccountID, newValue)
		}
	}

	var exportOPMLAccountID: String? {
		get {
			return AppDefaults.string(for: AppDefaultsKey.exportOPMLAccountID)
		}
		set {
			AppDefaults.setString(for: AppDefaultsKey.exportOPMLAccountID, newValue)
		}
	}

	var defaultBrowserID: String? {
		get {
			return AppDefaults.string(for: AppDefaultsKey.defaultBrowserID)
		}
		set {
			AppDefaults.setString(for: AppDefaultsKey.defaultBrowserID, newValue)
		}
	}

	var currentThemeName: String? {
		get {
			return AppDefaults.string(for: AppDefaultsKey.currentThemeName)
		}
		set {
			AppDefaults.setString(for: AppDefaultsKey.currentThemeName, newValue)
		}
	}

	var showTitleOnMainWindow: Bool {
		return AppDefaults.bool(for: AppDefaultsKey.showTitleOnMainWindow)
	}

	var showDebugMenu: Bool {
		return AppDefaults.bool(for: AppDefaultsKey.showDebugMenu)
 	}

	var feedDoubleClickMarkAsRead: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.feedDoubleClickMarkAsRead)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.feedDoubleClickMarkAsRead, newValue)
		}
	}

	var suppressSyncOnLaunch: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.suppressSyncOnLaunch)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.suppressSyncOnLaunch, newValue)
		}
	}

	var webInspectorEnabled: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.webInspectorEnabled)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.webInspectorEnabled, newValue)
		}
	}

	var webInspectorStartsAttached: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.webInspectorStartsAttached)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.webInspectorStartsAttached, newValue)
		}
	}

	var timelineSortDirection: ComparisonResult {
		get {
			return AppDefaults.sortDirection(for: AppDefaultsKey.timelineSortDirection)
		}
		set {
			AppDefaults.setSortDirection(for: AppDefaultsKey.timelineSortDirection, newValue)
		}
	}

	var timelineGroupByFeed: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.timelineGroupByFeed)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.timelineGroupByFeed, newValue)
		}
	}

	var timelineShowsSeparators: Bool {
		return AppDefaults.bool(for: AppDefaultsKey.timelineShowsSeparators)
	}

	var articleTextSize: ArticleTextSize {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: AppDefaultsKey.articleTextSize)
			return ArticleTextSize(rawValue: rawValue) ?? ArticleTextSize.large
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: AppDefaultsKey.articleTextSize)
		}
	}

	var refreshInterval: RefreshInterval {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: AppDefaultsKey.refreshInterval)
			return RefreshInterval(rawValue: rawValue) ?? RefreshInterval.everyHour
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: AppDefaultsKey.refreshInterval)
		}
	}

	var isArticleContentJavascriptEnabled: Bool {
		get {
			UserDefaults.standard.bool(forKey: AppDefaultsKey.articleContentJavascriptEnabled)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: AppDefaultsKey.articleContentJavascriptEnabled)
		}
	}

	func registerDefaults() {
		#if DEBUG
 		let showDebugMenu = true
 		#else
 		let showDebugMenu = false
 		#endif

		let defaults: [String: Any] = [
			AppDefaultsKey.sidebarFontSize: FontSize.medium.rawValue,
			AppDefaultsKey.timelineFontSize: FontSize.medium.rawValue,
			AppDefaultsKey.detailFontSize: FontSize.medium.rawValue,
			AppDefaultsKey.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
			AppDefaultsKey.timelineGroupByFeed: false,
			"NSScrollViewShouldScrollUnderTitlebar": false,
			AppDefaultsKey.refreshInterval: RefreshInterval.everyHour.rawValue,
			AppDefaultsKey.showDebugMenu: showDebugMenu,
			AppDefaultsKey.currentThemeName: Self.defaultThemeName,
			AppDefaultsKey.articleContentJavascriptEnabled: true
		]

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
			return AppDefaults.date(for: AppDefaultsKey.firstRunDate)
		}
		set {
			AppDefaults.setDate(for: AppDefaultsKey.firstRunDate, newValue)
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

	static func sortDirection(for key: String) -> ComparisonResult {
		let rawInt = int(for: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}

	static func setSortDirection(for key: String, _ value: ComparisonResult) {
		if value == .orderedAscending {
			setInt(for: key, ComparisonResult.orderedAscending.rawValue)
		} else {
			setInt(for: key, ComparisonResult.orderedDescending.rawValue)
		}
	}
}
