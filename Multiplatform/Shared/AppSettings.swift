//
//  AppSettings.swift
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

final class AppSettings: ObservableObject {
	
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
	
	public static let shared = AppSettings()
	private init() {}
	
	struct Key {
		static let refreshInterval = "refreshInterval"
		static let hideDockUnreadCount = "JustinMillerHideDockUnreadCount"
		static let userInterfaceColorPalette = "userInterfaceColorPalette"
		static let activeExtensionPointIDs = "activeExtensionPointIDs"
		static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
		static let firstRunDate = "firstRunDate"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let refreshClearsReadArticles = "refreshClearsReadArticles"
		static let timelineNumberOfLines = "timelineNumberOfLines"
		static let timelineIconSize = "timelineIconSize"
		static let timelineSortDirection = "timelineSortDirection"
		static let articleFullscreenAvailable = "articleFullscreenAvailable"
		static let articleFullscreenEnabled = "articleFullscreenEnabled"
		static let confirmMarkAllAsRead = "confirmMarkAllAsRead"
		static let lastRefresh = "lastRefresh"
		static let addWebFeedAccountID = "addWebFeedAccountID"
		static let addWebFeedFolderName = "addWebFeedFolderName"
		static let addFolderAccountID = "addFolderAccountID"
	}
	
	// MARK:  Development Builds
	let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()
	
	// MARK: First Run Details
	func isFirstRun() -> Bool {
		if let _ = AppSettings.store.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}
	
	var firstRunDate: Date? {
		set {
			AppSettings.store.setValue(newValue, forKey: Key.firstRunDate)
			objectWillChange.send()
		}
		get {
			AppSettings.store.object(forKey: Key.firstRunDate) as? Date
		}
	}
	
	// MARK: Refresh Timings
	@AppStorage(wrappedValue: RefreshInterval.everyHour, Key.refreshInterval, store: store) var refreshInterval: RefreshInterval
	
	// MARK: Dock Badge
	@AppStorage(wrappedValue: false, Key.hideDockUnreadCount, store: store) var hideDockUnreadCount
	
	// MARK: Color Palette
	var userInterfaceColorPalette: UserInterfaceColorPalette {
		get {
			if let palette = UserInterfaceColorPalette(rawValue: AppSettings.store.integer(forKey: Key.userInterfaceColorPalette)) {
				return palette
			}
			return .automatic
		}
		set {
			AppSettings.store.set(newValue.rawValue, forKey: Key.userInterfaceColorPalette)
			objectWillChange.send()
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
			return AppSettings.store.object(forKey: Key.activeExtensionPointIDs) as? [[AnyHashable : AnyHashable]]
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.activeExtensionPointIDs)
			objectWillChange.send()
		}
	}
	
	// MARK: Image Cache
	var lastImageCacheFlushDate: Date? {
		set {
			AppSettings.store.setValue(newValue, forKey: Key.lastImageCacheFlushDate)
			objectWillChange.send()
		}
		get {
			AppSettings.store.object(forKey: Key.lastImageCacheFlushDate) as? Date
		}
	}
	
	// MARK: Timeline
	@AppStorage(wrappedValue: false, Key.timelineGroupByFeed, store: store) var timelineGroupByFeed: Bool
	
	@AppStorage(wrappedValue: 3, Key.timelineNumberOfLines, store: store) var timelineNumberOfLines: Int {
		didSet {
			objectWillChange.send()
		}
	}
	
	@AppStorage(wrappedValue: 40.0, Key.timelineIconSize, store: store) var timelineIconSize: Double {
		didSet {
			objectWillChange.send()
		}
	}
	
	/// Set to `true` to sort oldest to newest, `false` for newest to oldest. Default is `false`.
	@AppStorage(wrappedValue: false, Key.timelineSortDirection, store: store) var timelineSortDirection: Bool
	
	// MARK: Refresh
	@AppStorage(wrappedValue: false, Key.refreshClearsReadArticles, store: store) var refreshClearsReadArticles: Bool
	
	// MARK: Articles
	@AppStorage(wrappedValue: false, Key.articleFullscreenAvailable, store: store) var articleFullscreenAvailable: Bool
	
	// MARK: Refresh
	var lastRefresh: Date? {
		set {
			AppSettings.store.setValue(newValue, forKey: Key.lastRefresh)
			objectWillChange.send()
		}
		get {
			AppSettings.store.object(forKey: Key.lastRefresh) as? Date
		}
	}
	
}
