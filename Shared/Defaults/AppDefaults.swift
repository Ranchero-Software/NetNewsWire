//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/25/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#endif

struct AppDefaults {

	enum Key: String {
		case firstRunDate
		case lastImageCacheFlushDate
		case timelineGroupByFeed
		case timelineSortDirection
		case addFeedAccountID
		case addFeedFolderName
		case addFolderAccountID
		case currentThemeName
		case articleContentJavascriptEnabled

#if os(macOS)
		case windowState
		case sidebarFontSize
		case timelineFontSize
		case detailFontSize
		case openInBrowserInBackground
		case subscribeToFeedsInDefaultBrowser
		case articleTextSize
		case refreshInterval
		case importOPMLAccountID
		case exportOPMLAccountID
		case defaultBrowserID

		case webInspectorEnabled = "WebInspectorEnabled"
		case webInspectorStartsAttached = "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached"

		// Hidden prefs
		case showDebugMenu
		case timelineShowsSeparators = "CorreiaSeparators"
		case showTitleOnMainWindow = "KafasisTitleMode"
		case feedDoubleClickMarkAsRead = "GruberFeedDoubleClickMarkAsRead"
		case suppressSyncOnLaunch = "DevroeSuppressSyncOnLaunch"

#elseif os(iOS)
		case userInterfaceColorPalette
		case refreshClearsReadArticles
		case timelineNumberOfLines
		case timelineIconDimension = "timelineIconSize"
		case articleFullscreenAvailable
		case articleFullscreenEnabled
		case confirmMarkAllAsRead
		case lastRefresh
		case useSystemBrowser
#endif
	}

	static let defaultThemeName = "Default"

	static let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()

	static let isFirstRun: Bool = {
		if firstRunDate == nil {
			firstRunDate = Date()
			return true
		}
		return false
	}()

#if os(macOS)
	static func registerDefaults() {

#if DEBUG
		let showDebugMenu = true
#else
		let showDebugMenu = false
#endif

		let defaults: [String: Any] = [
			Key.sidebarFontSize.rawValue: FontSize.medium.rawValue,
			Key.timelineFontSize.rawValue: FontSize.medium.rawValue,
			Key.detailFontSize.rawValue: FontSize.medium.rawValue,
			Key.timelineSortDirection.rawValue: ComparisonResult.orderedDescending.rawValue,
			Key.timelineGroupByFeed.rawValue: false,
			Key.refreshInterval.rawValue: RefreshInterval.everyHour.rawValue,
			Key.showDebugMenu.rawValue: showDebugMenu,
			Key.currentThemeName.rawValue: Self.defaultThemeName,
			Key.articleContentJavascriptEnabled.rawValue: true,
			"NSScrollViewShouldScrollUnderTitlebar": false
		]
		UserDefaults.standard.register(defaults: defaults)
	}
#elseif os(iOS)

	static func registerDefaults() {

		// TODO: migrate all (or as many as possible) out of shared
		let sharedDefaults: [String: Any] = [
			Key.userInterfaceColorPalette.rawValue: UserInterfaceColorPalette.automatic.rawValue,
			Key.timelineGroupByFeed.rawValue: false,
			Key.refreshClearsReadArticles.rawValue: false,
			Key.timelineNumberOfLines.rawValue: 2,
			Key.timelineIconDimension.rawValue: IconSize.medium.rawValue,
			Key.timelineSortDirection.rawValue: ComparisonResult.orderedDescending.rawValue,
			Key.articleFullscreenAvailable.rawValue: false,
			Key.articleFullscreenEnabled.rawValue: false,
			Key.confirmMarkAllAsRead.rawValue: true
		]
		appGroupStorage.register(defaults: sharedDefaults)

		let defaults: [String: Any] = [
			Key.currentThemeName.rawValue: Self.defaultThemeName,
			Key.articleContentJavascriptEnabled.rawValue: true
		]
		UserDefaults.standard.register(defaults: defaults)
	}
#endif

	static var addFeedAccountID: String? {
		get {
			string(key: .addFeedAccountID)
		}
		set {
			setString(newValue, key: .addFeedAccountID)
		}
	}

	static var addFeedFolderName: String? {
		get {
			string(key: .addFeedFolderName)
		}
		set {
			setString(newValue, key: .addFeedFolderName)
		}
	}

	static var addFolderAccountID: String? {
		get {
			string(key: .addFolderAccountID)
		}
		set {
			setString(newValue, key: .addFolderAccountID)
		}
	}

	static var currentThemeName: String? {
		get {
			string(key: .currentThemeName)
		}
		set {
			setString(newValue, key: .currentThemeName)
		}
	}

	static var isArticleContentJavascriptEnabled: Bool {
		get {
			bool(key: .articleContentJavascriptEnabled)
		}
		set {
			setBool(newValue, key: .articleContentJavascriptEnabled)
		}
	}

#if os(macOS)
	static var timelineGroupByFeed: Bool {
		get {
			bool(key: .timelineGroupByFeed)
		}
		set {
			setBool(newValue, key: .timelineGroupByFeed)
		}
	}
#elseif os(iOS)
	static var timelineGroupByFeed: Bool {
		// TODO: migrate to not shared
		get {
			sharedBool(key: .timelineGroupByFeed)
		}
		set {
			setSharedBool(newValue, key: .timelineGroupByFeed)
		}
	}
#endif

#if os(macOS)
	static var timelineSortDirection: ComparisonResult {
		get {
			sortDirection(key: .timelineSortDirection)
		}
		set {
			setSortDirection(newValue, key: .timelineSortDirection)
		}
	}
#else
	static var timelineSortDirection: ComparisonResult {
		// TODO: migrate to not shared
		get {
			sharedSortDirection(key: .timelineSortDirection)
		}
		set {
			setSharedSortDirection(newValue, key: .timelineSortDirection)
		}
	}
#endif

#if os(macOS)
	static var lastImageCacheFlushDate: Date? {
		get {
			date(key: .lastImageCacheFlushDate)
		}
		set {
			setDate(newValue, key: .lastImageCacheFlushDate)
		}
	}
#else
	static var lastImageCacheFlushDate: Date? {
		// TODO: migrate to not shared
		get {
			sharedDate(key: .lastImageCacheFlushDate)
		}
		set {
			setSharedDate(newValue, key: .lastImageCacheFlushDate)
		}
	}
#endif
}

// MARK: - Mac-only Defaults

#if os(macOS)

extension AppDefaults {

	static var windowState: [AnyHashable: Any]? {
		get {
			UserDefaults.standard.object(forKey: Key.windowState.rawValue) as? [AnyHashable: Any]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.windowState.rawValue)
		}
	}

	static var sidebarFontSize: FontSize {
		get {
			fontSize(key: .sidebarFontSize)
		}
		set {
			setFontSize(newValue, key: .sidebarFontSize)
		}
	}

	static var timelineFontSize: FontSize {
		get {
			fontSize(key: .timelineFontSize)
		}
		set {
			setFontSize(newValue, key: .timelineFontSize)
		}
	}

	static var detailFontSize: FontSize {
		get {
			fontSize(key: .detailFontSize)
		}
		set {
			setFontSize(newValue, key: .detailFontSize)
		}
	}

	static var importOPMLAccountID: String? {
		get {
			string(key: .importOPMLAccountID)
		}
		set {
			setString(newValue, key: .importOPMLAccountID)
		}
	}

	static var exportOPMLAccountID: String? {
		get {
			string(key: .exportOPMLAccountID)
		}
		set {
			setString(newValue, key: .exportOPMLAccountID)
		}
	}

	static var defaultBrowserID: String? {
		get {
			string(key: .defaultBrowserID)
		}
		set {
			setString(newValue, key: .defaultBrowserID)
		}
	}

	static var refreshInterval: RefreshInterval {
		get {
			let rawValue = int(key: .refreshInterval)
			return RefreshInterval(rawValue: rawValue) ?? RefreshInterval.everyHour
		}
		set {
			setInt(newValue.rawValue, key: .refreshInterval)
		}
	}

	static var openInBrowserInBackground: Bool {
		get {
			bool(key: .openInBrowserInBackground)
		}
		set {
			setBool(newValue, key: .openInBrowserInBackground)
		}
	}

	/// Shared with Subscribe to Feed Safari extension.
	static var subscribeToFeedsInDefaultBrowser: Bool {
		get {
			sharedBool(key: .subscribeToFeedsInDefaultBrowser)
		}
		set {
			setSharedBool(newValue, key: .subscribeToFeedsInDefaultBrowser)
		}
	}

	static var articleTextSize: ArticleTextSize {
		get {
			let rawValue = int(key: .articleTextSize)
			return ArticleTextSize(rawValue: rawValue) ?? ArticleTextSize.large
		}
		set {
			setInt(newValue.rawValue, key: .articleTextSize)
		}
	}

	static var webInspectorEnabled: Bool {
		get {
			bool(key: .webInspectorEnabled)
		}
		set {
			setBool(newValue, key: .webInspectorEnabled)
		}
	}

	static var webInspectorStartsAttached: Bool {
		get {
			bool(key: .webInspectorStartsAttached)
		}
		set {
			setBool(newValue, key: .webInspectorStartsAttached)
		}
	}

	private static let smallestFontSizeRawValue = FontSize.small.rawValue
	private static let largestFontSizeRawValue = FontSize.veryLarge.rawValue

	static func fontSize(key: Key) -> FontSize {
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

	static func setFontSize(_ fontSize: FontSize, key: Key) {
		setInt(fontSize.rawValue, key: key)
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

	// MARK: - Hidden prefs

	static var showTitleOnMainWindow: Bool {
		bool(key: .showTitleOnMainWindow)
	}

	static var showDebugMenu: Bool {
		bool(key: .showDebugMenu)
	}

	static var suppressSyncOnLaunch: Bool {
		bool(key: .suppressSyncOnLaunch)
	}

	static var timelineShowsSeparators: Bool {
		bool(key: .timelineShowsSeparators)
	}

	static var feedDoubleClickMarkAsRead: Bool {
		bool(key: .feedDoubleClickMarkAsRead)
	}
}

#endif

// MARK: - iOS-only Defaults

#if os(iOS)

extension AppDefaults {

	static var userInterfaceColorPalette: UserInterfaceColorPalette {
		// TODO: migrate to not shared
		get {
			if let result = UserInterfaceColorPalette(rawValue: sharedInt(key: .userInterfaceColorPalette)) {
				return result
			}
			return .automatic
		}
		set {
			setSharedInt(newValue.rawValue, key: .userInterfaceColorPalette)
		}
	}

	static var refreshClearsReadArticles: Bool {
		// TODO: migrate to not shared
		get {
			sharedBool(key: .refreshClearsReadArticles)
		}
		set {
			setSharedBool(newValue, key: .refreshClearsReadArticles)
		}
	}

	static var useSystemBrowser: Bool {
		get {
			bool(key: .useSystemBrowser)
		}
		set {
			setBool(newValue, key: .useSystemBrowser)
		}
	}

	static var timelineIconSize: IconSize {
		// TODO: migrate to not shared
		get {
			let rawValue = sharedInt(key: .timelineIconDimension)
			return IconSize(rawValue: rawValue) ?? IconSize.medium
		}
		set {
			setSharedInt(newValue.rawValue, key: .timelineIconDimension)
		}
	}

	static var articleFullscreenAvailable: Bool {
		// TODO: migrate to not shared
		get {
			sharedBool(key: .articleFullscreenAvailable)
		}
		set {
			setSharedBool(newValue, key: .articleFullscreenAvailable)
		}
	}

	static var articleFullscreenEnabled: Bool {
		// TODO: migrate to not shared
		get {
			sharedBool(key: .articleFullscreenEnabled)
		}
		set {
			setSharedBool(newValue, key: .articleFullscreenEnabled)
		}
	}

	static var logicalArticleFullscreenEnabled: Bool {
		articleFullscreenAvailable && articleFullscreenEnabled
	}

	static var confirmMarkAllAsRead: Bool {
		// TODO: migrate to not shared
		get {
			sharedBool(key: .confirmMarkAllAsRead)
		}
		set {
			setSharedBool(newValue, key: .confirmMarkAllAsRead)
		}
	}

	static var lastRefresh: Date? {
		// TODO: migrate to not shared
		get {
			sharedDate(key: .lastRefresh)
		}
		set {
			setSharedDate(newValue, key: .lastRefresh)
		}
	}

	static var timelineNumberOfLines: Int {
		// TODO: migrate to not shared
		get {
			sharedInt(key: .timelineNumberOfLines)
		}
		set {
			setSharedInt(newValue, key: .timelineNumberOfLines)
		}
	}
}

#endif

// MARK: - Private

private extension AppDefaults {

#if os(macOS)
	static var firstRunDate: Date? {
		get {
			date(key: .firstRunDate)
		}
		set {
			setDate(newValue, key: .firstRunDate)
		}
	}
#elseif os(iOS)
	static var firstRunDate: Date? {
		get {
			sharedDate(key: .firstRunDate)
		}
		set {
			setSharedDate(newValue, key: .firstRunDate)
		}
	}
#endif

	static func bool(key: Key) -> Bool {
		UserDefaults.standard.bool(forKey: key.rawValue)
	}

	static func setBool(_ flag: Bool, key: Key) {
		UserDefaults.standard.set(flag, forKey: key.rawValue)
	}

	static func int(key: Key) -> Int {
		UserDefaults.standard.integer(forKey: key.rawValue)
	}

	static func setInt(_ x: Int, key: Key) {
		UserDefaults.standard.set(x, forKey: key.rawValue)
	}

	static func date(key: Key) -> Date? {
		UserDefaults.standard.object(forKey: key.rawValue) as? Date
	}

	static func setDate(_ date: Date?, key: Key) {
		UserDefaults.standard.set(date, forKey: key.rawValue)
	}

	static func string(key: Key) -> String? {
		return UserDefaults.standard.string(forKey: key.rawValue)
	}

	static func setString(_ value: String?, key: Key) {
		UserDefaults.standard.set(value, forKey: key.rawValue)
	}

	static func sortDirection(key: Key) -> ComparisonResult {
		let rawInt = int(key: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}

	static func setSortDirection(_ value: ComparisonResult, key: Key) {
		if value == .orderedAscending {
			setInt(ComparisonResult.orderedAscending.rawValue, key: key)
		} else {
			setInt(ComparisonResult.orderedDescending.rawValue, key: key)
		}
	}
}

// MARK: - App Group Storage

// These are for preferences that are shared between the app and extensions and widgets.
// These are to be used *only* for preferences for that are actually shared, which should be rare.

private extension AppDefaults {

	static var appGroupStorage: UserDefaults = {

#if os(macOS)
		let appGroupSuiteName = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
#elseif os(iOS)
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		let appGroupSuiteName = "\(appIdentifierPrefix)group.\(Bundle.main.bundleIdentifier!)"
#endif

		return UserDefaults(suiteName: appGroupSuiteName)!
	}()

	static func sharedBool(key: Key) -> Bool {
		appGroupStorage.bool(forKey: key.rawValue)
	}

	static func setSharedBool(_ flag: Bool, key: Key) {
		appGroupStorage.set(flag, forKey: key.rawValue)
	}

#if os(iOS)
	static func sharedInt(key: Key) -> Int {
		appGroupStorage.integer(forKey: key.rawValue)
	}

	static func setSharedInt(_ x: Int, key: Key) {
		appGroupStorage.set(x, forKey: key.rawValue)
	}

	static func sharedDate(key: Key) -> Date? {
		appGroupStorage.object(forKey: key.rawValue) as? Date
	}

	static func setSharedDate(_ date: Date?, key: Key) {
		appGroupStorage.set(date, forKey: key.rawValue)
	}

	static func sharedSortDirection(key: Key) -> ComparisonResult {
		let rawInt = sharedInt(key: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}

	static func setSharedSortDirection(_ value: ComparisonResult, key: Key) {
		if value == .orderedAscending {
			setSharedInt(ComparisonResult.orderedAscending.rawValue, key: key)
		} else {
			setSharedInt(ComparisonResult.orderedDescending.rawValue, key: key)
		}
	}
#endif
}
