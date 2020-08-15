//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 1/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import SwiftUI

enum UserInterfaceColorPalette: Int, CustomStringConvertible, CaseIterable {
	case automatic = 0
	case light = 1
	case dark = 2

	var description: String {
		switch self {
		case .automatic:
			return NSLocalizedString("Automatic", comment: "Automatic")
		case .light:
			return NSLocalizedString("Light", comment: "Light")
		case .dark:
			return NSLocalizedString("Dark", comment: "Dark")
		}
	}
}

final class AppDefaults: ObservableObject {
	
	#if os(macOS)
	static let store: UserDefaults = UserDefaults.standard
	#endif
	
	#if os(iOS)
	static let store: UserDefaults = {
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		let suiteName = "\(appIdentifierPrefix)group.\(Bundle.main.bundleIdentifier!)"
		return UserDefaults.init(suiteName: suiteName)!
	}()
	#endif
	
	public static let shared = AppDefaults()
	private init() {}
	
	struct Key {
		
		// Shared Defaults
		static let refreshInterval = "refreshInterval"
		static let hideDockUnreadCount = "JustinMillerHideDockUnreadCount"
		static let activeExtensionPointIDs = "activeExtensionPointIDs"
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let firstRunDate = "firstRunDate"
		static let lastRefresh = "lastRefresh"
		static let addWebFeedAccountID = "addWebFeedAccountID"
		static let addWebFeedFolderName = "addWebFeedFolderName"
		static let addFolderAccountID = "addFolderAccountID"
				
		static let userInterfaceColorPalette = "userInterfaceColorPalette"
		static let timelineSortDirection = "timelineSortDirection"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let timelineIconDimensions = "timelineIconDimensions"
		static let timelineNumberOfLines = "timelineNumberOfLines"
		
		// Sidebar Defaults
		static let sidebarConfirmDelete = "sidebarConfirmDelete"

		// iOS Defaults
		static let refreshClearsReadArticles = "refreshClearsReadArticles"
		static let articleFullscreenAvailable = "articleFullscreenAvailable"
		static let articleFullscreenEnabled = "articleFullscreenEnabled" 
		static let confirmMarkAllAsRead = "confirmMarkAllAsRead" 
		
		// macOS Defaults
		static let openInBrowserInBackground = "openInBrowserInBackground"
		static let defaultBrowserID = "defaultBrowserID"
		static let checkForUpdatesAutomatically = "checkForUpdatesAutomatically"
		static let downloadTestBuilds = "downloadTestBuild"
		static let sendCrashLogs = "sendCrashLogs"
		
		// Hidden macOS Defaults
		static let showDebugMenu = "ShowDebugMenu"
		static let timelineShowsSeparators = "CorreiaSeparators"
		static let showTitleOnMainWindow = "KafasisTitleMode"
		
		#if !MAC_APP_STORE
			static let webInspectorEnabled = "WebInspectorEnabled"
			static let webInspectorStartsAttached = "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached"
		#endif
		
	}
	
	// MARK:  Development Builds
	let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()
	
	// MARK: First Run Details
	var firstRunDate: Date? {
		set {
			AppDefaults.store.setValue(newValue, forKey: Key.firstRunDate)
			objectWillChange.send()
		}
		get {
			AppDefaults.store.object(forKey: Key.firstRunDate) as? Date
		}
	}
	
	// MARK: Refresh Interval
	@AppStorage(wrappedValue: 4, Key.refreshInterval, store: store) var interval: Int {
		didSet {
			objectWillChange.send()
		}
	}
	
	var refreshInterval: RefreshInterval {
		RefreshInterval(rawValue: interval) ?? RefreshInterval.everyHour
	}
	
	// MARK: Dock Badge
	@AppStorage(wrappedValue: false, Key.hideDockUnreadCount, store: store) var hideDockUnreadCount {
		didSet {
			objectWillChange.send()
		}
	}
	
	// MARK: Color Palette
	var userInterfaceColorPalette: UserInterfaceColorPalette {
		get {
			if let palette = UserInterfaceColorPalette(rawValue: AppDefaults.store.integer(forKey: Key.userInterfaceColorPalette)) {
				return palette
			}
			return .automatic
		}
		set {
			AppDefaults.store.set(newValue.rawValue, forKey: Key.userInterfaceColorPalette)
			#if os(macOS)
			self.objectWillChange.send()
			#else
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
				self.objectWillChange.send()
			})
			#endif
		}
	}
	
	static var userInterfaceColorScheme: ColorScheme? {
		switch AppDefaults.shared.userInterfaceColorPalette {
		case .light:
			return ColorScheme.light
		case .dark:
			return ColorScheme.dark
		default:
			return nil
		}
	}
	
	// MARK: Feeds & Folders
	@AppStorage(Key.addWebFeedAccountID, store: store) var addWebFeedAccountID: String?
	
	@AppStorage(Key.addWebFeedFolderName, store: store) var addWebFeedFolderName: String? 
	
	@AppStorage(Key.addFolderAccountID, store: store) var addFolderAccountID: String?
	
	@AppStorage(wrappedValue: false, Key.confirmMarkAllAsRead, store: store) var confirmMarkAllAsRead: Bool
	
	// MARK: Extension Points
	var activeExtensionPointIDs: [[AnyHashable : AnyHashable]]? {
		get {
			return AppDefaults.store.object(forKey: Key.activeExtensionPointIDs) as? [[AnyHashable : AnyHashable]]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.activeExtensionPointIDs)
			objectWillChange.send()
		}
	}
	
	// MARK: Image Cache
	var lastImageCacheFlushDate: Date? {
		set {
			AppDefaults.store.setValue(newValue, forKey: Key.lastImageCacheFlushDate)
			objectWillChange.send()
		}
		get {
			AppDefaults.store.object(forKey: Key.lastImageCacheFlushDate) as? Date
		}
	}
	
	// MARK: Timeline
	@AppStorage(wrappedValue: false, Key.timelineGroupByFeed, store: store) var timelineGroupByFeed: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(wrappedValue: 2.0, Key.timelineNumberOfLines, store: store) var timelineNumberOfLines: Double {
		didSet {
			objectWillChange.send()
		}
	}

	@AppStorage(wrappedValue: 40.0, Key.timelineIconDimensions, store: store) var timelineIconDimensions: Double {
		didSet {
			objectWillChange.send()
		}
	}
	
	/// Set to `true` to sort oldest to newest, `false` for newest to oldest. Default is `false`.
	@AppStorage(wrappedValue: false, Key.timelineSortDirection, store: store) var timelineSortDirection: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	// MARK: Sidebar
	@AppStorage(wrappedValue: true, Key.sidebarConfirmDelete, store: store) var sidebarConfirmDelete: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	
	// MARK: Refresh
	@AppStorage(wrappedValue: false, Key.refreshClearsReadArticles, store: store) var refreshClearsReadArticles: Bool
	
	// MARK: Articles
	@AppStorage(wrappedValue: false, Key.articleFullscreenAvailable, store: store) var articleFullscreenAvailable: Bool
	
	@AppStorage(wrappedValue: false, Key.articleFullscreenEnabled, store: store) var articleFullscreenEnabled: Bool
	
	// MARK: Refresh
	var lastRefresh: Date? {
		set {
			AppDefaults.store.setValue(newValue, forKey: Key.lastRefresh)
			objectWillChange.send()
		}
		get {
			AppDefaults.store.object(forKey: Key.lastRefresh) as? Date
		}
	}
	
	// MARK: Window State
	@AppStorage(wrappedValue: false, Key.openInBrowserInBackground, store: store) var openInBrowserInBackground: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(Key.defaultBrowserID, store: store) var defaultBrowserID: String? {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(Key.showTitleOnMainWindow, store: store) var showTitleOnMainWindow: Bool? {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(wrappedValue: false, Key.showDebugMenu, store: store) var showDebugMenu: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(wrappedValue: false, Key.timelineShowsSeparators, store: store) var timelineShowsSeparators: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	#if !MAC_APP_STORE
	@AppStorage(wrappedValue: false, Key.webInspectorEnabled, store: store) var webInspectorEnabled: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(wrappedValue: false, Key.webInspectorStartsAttached, store: store) var webInspectorStartsAttached: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	#endif
	
	@AppStorage(wrappedValue: true, Key.checkForUpdatesAutomatically, store: store) var checkForUpdatesAutomatically: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(wrappedValue: false, Key.downloadTestBuilds, store: store) var downloadTestBuilds: Bool {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(wrappedValue: true, Key.sendCrashLogs, store: store) var sendCrashLogs: Bool {
		didSet {
			objectWillChange.send()
		}
	}

	static func registerDefaults() {
		let defaults: [String : Any] = [Key.userInterfaceColorPalette: UserInterfaceColorPalette.automatic.rawValue,
										Key.timelineGroupByFeed: false,
										Key.refreshClearsReadArticles: false,
										Key.timelineNumberOfLines: 2,
										Key.timelineIconDimensions: 40,
										Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
										Key.articleFullscreenAvailable: false,
										Key.articleFullscreenEnabled: false,
										Key.confirmMarkAllAsRead: true,
										"NSScrollViewShouldScrollUnderTitlebar": false,
										Key.refreshInterval: RefreshInterval.everyHour.rawValue]
		AppDefaults.store.register(defaults: defaults)
	}
	
}

extension AppDefaults {
	
	func isFirstRun() -> Bool {
		if let _ = AppDefaults.store.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}
	
}
