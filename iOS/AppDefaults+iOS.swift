//
//  AppDefaults+iOS.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import RSCore
import UIKit
import os
import Account
import Articles
import Images

enum UserInterfaceColorPalette: Int, CustomStringConvertible, CaseIterable {
	case automatic = 0
	case light = 1
	case dark = 2

	var description: String {
		switch self {
		case .automatic:
			NSLocalizedString("Automatic", comment: "Automatic")
		case .light:
			NSLocalizedString("Light", comment: "Light")
		case .dark:
			NSLocalizedString("Dark", comment: "Dark")
		}
	}
}

extension Notification.Name {
	public static let userInterfaceColorPaletteDidUpdate = Notification.Name("UserInterfaceColorPaletteDidUpdateNotification")
	public static let timelineIconSizeDidChange = Notification.Name("TimelineIconSizeDidChangeNotification")
	public static let timelineNumberOfLinesDidChange = Notification.Name("TimelineNumberOfLinesDidChangeNotification")
}

extension AppDefaults.Key {
	static let userInterfaceColorPalette = "userInterfaceColorPalette"
	static let refreshClearsReadArticles = "refreshClearsReadArticles"
	static let timelineNumberOfLines = "timelineNumberOfLines"
	static let timelineIconDimension = "timelineIconSize"
	static let articleFullscreenAvailable = "articleFullscreenAvailable"
	static let articleFullscreenEnabled = "articleFullscreenEnabled"
	static let confirmMarkAllAsRead = "confirmMarkAllAsRead"
	static let lastRefresh = "lastRefresh"
	static let useSystemBrowser = "useSystemBrowser"
	static let hideReadFeeds = "hideReadFeeds"
	static let isShowingExtractedArticle = "isShowingExtractedArticle"
	static let articleWindowScrollY = "articleWindowScrollY"
	static let expandedContainers = "expandedContainers"
	static let smartFeedsHidingReadArticles = "smartFeedsHidingReadArticles"
	static let feedsHidingReadArticles = "feedsHidingReadArticles"
	static let foldersShowingReadArticles = "foldersShowingReadArticles"
	static let selectedSidebarItem = "selectedSidebarItem"
	static let selectedArticle = "selectedArticle"
	static let didMigrateLegacyStateRestorationInfo = "didMigrateLegacyStateRestorationInfo"
	static let splitViewPreferredDisplayMode = "splitViewPreferredDisplayMode"
	static let timelineWidth = "timelineWidth"
	static let sidebarWidth = "sidebarWidth"
	static let didMigrateAppGroupDefaults = "didMigrateAppGroupDefaults"

	// Keys that used to be stored in the app-group suite.
	static let appGroupKeys = [userInterfaceColorPalette, lastImageCacheFlushDate, firstRunDate, timelineGroupByFeed, refreshClearsReadArticles, timelineNumberOfLines, timelineIconDimension, timelineSortDirection, articleFullscreenAvailable, articleFullscreenEnabled, confirmMarkAllAsRead, articleContentJavascriptEnabled, splitViewPreferredDisplayMode, lastRefresh]
}

extension AppDefaults {

	fileprivate static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "AppDefaults")

	static var userInterfaceColorPalette: UserInterfaceColorPalette {
		get {
			if let result = UserInterfaceColorPalette(rawValue: UserDefaults.standard.integer(forKey: Key.userInterfaceColorPalette)) {
				return result
			}
			return .automatic
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.userInterfaceColorPalette)
			NotificationCenter.default.post(name: .userInterfaceColorPaletteDidUpdate, object: self)
		}
	}

	static var useSystemBrowser: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.useSystemBrowser)
		}
		set {
			UserDefaults.standard.setValue(newValue, forKey: Key.useSystemBrowser)
		}
	}

	static var timelineGroupByFeed: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.timelineGroupByFeed)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.timelineGroupByFeed)
		}
	}

	static var refreshClearsReadArticles: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.refreshClearsReadArticles)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.refreshClearsReadArticles)
		}
	}

	static var timelineSortDirection: ComparisonResult {
		get {
			AppDefaults.sortDirection(for: Key.timelineSortDirection)
		}
		set {
			AppDefaults.setSortDirection(for: Key.timelineSortDirection, newValue)
		}
	}

	static var articleFullscreenAvailable: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.articleFullscreenAvailable)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.articleFullscreenAvailable)
		}
	}

	static var articleFullscreenEnabled: Bool {
		get {
			articleFullscreenAvailable && UserDefaults.standard.bool(forKey: Key.articleFullscreenEnabled)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.articleFullscreenEnabled)
		}
	}

	static var logicalArticleFullscreenEnabled: Bool {
		articleFullscreenAvailable && articleFullscreenEnabled
	}

	static var confirmMarkAllAsRead: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.confirmMarkAllAsRead)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.confirmMarkAllAsRead)
		}
	}

	static var splitViewPreferredDisplayMode: Int {
		get {
			UserDefaults.standard.integer(forKey: Key.splitViewPreferredDisplayMode)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.splitViewPreferredDisplayMode)
		}
	}

	// The iPad timeline column width. nil until the user has resized it.
	static var timelineWidth: Int? {
		get {
			UserDefaults.standard.object(forKey: Key.timelineWidth) as? Int
		}
		set {
			if let newValue {
				UserDefaults.standard.set(newValue, forKey: Key.timelineWidth)
			} else {
				UserDefaults.standard.removeObject(forKey: Key.timelineWidth)
			}
		}
	}

	// The iPad sidebar column width. nil until the user has resized it.
	static var sidebarWidth: Int? {
		get {
			UserDefaults.standard.object(forKey: Key.sidebarWidth) as? Int
		}
		set {
			if let newValue {
				UserDefaults.standard.set(newValue, forKey: Key.sidebarWidth)
			} else {
				UserDefaults.standard.removeObject(forKey: Key.sidebarWidth)
			}
		}
	}

	static var lastRefresh: Date? {
		get {
			AppDefaults.date(for: Key.lastRefresh)
		}
		set {
			AppDefaults.setDate(for: Key.lastRefresh, newValue)
		}
	}

	static var timelineNumberOfLines: Int {
		get {
			UserDefaults.standard.integer(forKey: Key.timelineNumberOfLines)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.timelineNumberOfLines)
			NotificationCenter.default.post(name: .timelineNumberOfLinesDidChange, object: nil)
		}
	}

	static var timelineIconSize: IconSize {
		get {
			let rawValue = UserDefaults.standard.integer(forKey: Key.timelineIconDimension)
			return IconSize(rawValue: rawValue) ?? IconSize.medium
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.timelineIconDimension)
			NotificationCenter.default.post(name: .timelineIconSizeDidChange, object: nil)
		}
	}

	static var hideReadFeeds: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.hideReadFeeds)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.hideReadFeeds)
		}
	}

	static var isShowingExtractedArticle: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.isShowingExtractedArticle)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.isShowingExtractedArticle)
		}
	}

	static var articleWindowScrollY: Int {
		get {
			UserDefaults.standard.integer(forKey: Key.articleWindowScrollY)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.articleWindowScrollY)
		}
	}

	static var expandedContainers: Set<ContainerIdentifier> {
		get {
			guard let rawIdentifiers = UserDefaults.standard.array(forKey: Key.expandedContainers) as? [[String: String]] else {
				return Set<ContainerIdentifier>()
			}
			let containerIdentifiers = rawIdentifiers.compactMap { ContainerIdentifier(userInfo: $0) }
			return Set(containerIdentifiers)
		}
		set {
			Self.logger.debug("AppDefaults: set expandedContainers: \(newValue)")
			let containerIdentifierUserInfos = newValue.compactMap { $0.userInfo }
			UserDefaults.standard.set(containerIdentifierUserInfos, forKey: Key.expandedContainers)
		}
	}

	static var smartFeedsHidingReadArticles: Set<String> {
		get {
			let smartFeedIDs = UserDefaults.standard.array(forKey: Key.smartFeedsHidingReadArticles) as? [String] ?? []
			return Set(smartFeedIDs)
		}
		set {
			let array = Array(newValue)
			UserDefaults.standard.set(array, forKey: Key.smartFeedsHidingReadArticles)
		}
	}

	static var feedsHidingReadArticles: [String: Set<String>] { // Account id: Set<feed.feedID>
		get {
			guard let d = UserDefaults.standard.dictionary(forKey: Key.feedsHidingReadArticles) as? [String: [String]] else {
				return [String: Set<String>]()
			}
			return d.mapValues { Set($0) }
		}
		set {
			let d = newValue.mapValues { Array($0) }
			UserDefaults.standard.set(d, forKey: Key.feedsHidingReadArticles)
		}
	}

	static var foldersShowingReadArticles: [String: Set<String>] { // Account id: Set<folder.nameForDisplay>
		get {
			guard let d = UserDefaults.standard.dictionary(forKey: Key.foldersShowingReadArticles) as? [String: [String]] else {
				return [String: Set<String>]()
			}
			return d.mapValues { Set($0) }
		}
		set {
			let d = newValue.mapValues { Array($0) }
			UserDefaults.standard.set(d, forKey: Key.foldersShowingReadArticles)
		}
	}

	static var selectedSidebarItem: SidebarItemIdentifier? {
		get {
			guard let userInfo = UserDefaults.standard.dictionary(forKey: Key.selectedSidebarItem) as? [String: String] else {
				return nil
			}
			return SidebarItemIdentifier(userInfo: userInfo)
		}
		set {
			guard let newValue else {
				UserDefaults.standard.removeObject(forKey: Key.selectedSidebarItem)
				return
			}
			UserDefaults.standard.set(newValue.userInfo, forKey: Key.selectedSidebarItem)
		}
	}

	static var selectedArticle: ArticleSpecifier? {
		get {
			guard let d = UserDefaults.standard.dictionary(forKey: Key.selectedArticle) as? [String: String] else {
				return nil
			}
			return ArticleSpecifier(dictionary: d)
		}
		set {
			guard let newValue else {
				UserDefaults.standard.removeObject(forKey: Key.selectedArticle)
				return
			}
			UserDefaults.standard.set(newValue.dictionary, forKey: Key.selectedArticle)
		}
	}

	static var didMigrateLegacyStateRestorationInfo: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.didMigrateLegacyStateRestorationInfo)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.didMigrateLegacyStateRestorationInfo)
		}
	}

	@MainActor static func registerDefaults() {
		// Must run before register(defaults:) so registered values aren’t copied as explicit ones.
		migrateAppGroupDefaultsIfNeeded()

		let platformDefaults: [String: Any] = [
			Key.userInterfaceColorPalette: UserInterfaceColorPalette.automatic.rawValue,
			Key.refreshClearsReadArticles: false,
			Key.timelineNumberOfLines: 2,
			Key.timelineIconDimension: IconSize.medium.rawValue,
			Key.articleFullscreenAvailable: false,
			Key.articleFullscreenEnabled: false,
			Key.confirmMarkAllAsRead: true,
			Key.splitViewPreferredDisplayMode: UISplitViewController.DisplayMode.oneBesideSecondary.rawValue
		]

		let defaults = commonRegisteredDefaults.merging(platformDefaults) { _, platformValue in platformValue }
		UserDefaults.standard.register(defaults: defaults)
	}

	/// Copies each key’s value from source to destination, unless destination already has a value.
	static func migrate(from source: UserDefaults, to destination: UserDefaults, keys: [String]) {
		for key in keys {
			if let value = source.object(forKey: key), destination.object(forKey: key) == nil {
				destination.set(value, forKey: key)
			}
		}
	}
}

private extension AppDefaults {

	/// Moves settings from the app-group suite to UserDefaults.standard, then deletes the suite.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/5466>
	static func migrateAppGroupDefaultsIfNeeded() {
		guard !UserDefaults.standard.bool(forKey: Key.didMigrateAppGroupDefaults) else {
			return
		}
		UserDefaults.standard.set(true, forKey: Key.didMigrateAppGroupDefaults)

		guard let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String, let bundleIdentifier = Bundle.main.bundleIdentifier else {
			return
		}
		let suiteName = "\(appIdentifierPrefix)group.\(bundleIdentifier)"
		guard let appGroupDefaults = UserDefaults(suiteName: suiteName) else {
			return
		}
		migrate(from: appGroupDefaults, to: UserDefaults.standard, keys: Key.appGroupKeys)
		appGroupDefaults.removePersistentDomain(forName: suiteName)
	}

	static func setSortDirection(for key: String, _ value: ComparisonResult) {
		if value == .orderedAscending {
			UserDefaults.standard.set(ComparisonResult.orderedAscending.rawValue, forKey: key)
		} else {
			UserDefaults.standard.set(ComparisonResult.orderedDescending.rawValue, forKey: key)
		}
	}
}

struct StateRestorationInfo {
	let hideReadFeeds: Bool
	let expandedContainers: Set<ContainerIdentifier>
	let selectedSidebarItem: SidebarItemIdentifier?
	let smartFeedsHidingReadArticles: Set<String>
	let feedsHidingReadArticles: [String: Set<String>]
	let foldersShowingReadArticles: [String: Set<String>]
	let selectedArticle: ArticleSpecifier?
	let articleWindowScrollY: Int
	let isShowingExtractedArticle: Bool

	init(hideReadFeeds: Bool,
	     expandedContainers: Set<ContainerIdentifier>,
	     selectedSidebarItem: SidebarItemIdentifier?,
	     smartFeedsHidingReadArticles: Set<String>,
	     feedsHidingReadArticles: [String: Set<String>],
	     foldersShowingReadArticles: [String: Set<String>],
	     selectedArticle: ArticleSpecifier?,
	     articleWindowScrollY: Int,
	     isShowingExtractedArticle: Bool) {
		self.hideReadFeeds = hideReadFeeds
		self.expandedContainers = expandedContainers
		self.selectedSidebarItem = selectedSidebarItem
		self.smartFeedsHidingReadArticles = smartFeedsHidingReadArticles
		self.feedsHidingReadArticles = feedsHidingReadArticles
		self.foldersShowingReadArticles = foldersShowingReadArticles
		self.selectedArticle = selectedArticle
		self.articleWindowScrollY = articleWindowScrollY
		self.isShowingExtractedArticle = isShowingExtractedArticle

		AppDefaults.logger.debug("AppDefaults: StateRestorationInfo:\nexpandedContainers: \(expandedContainers)\nselectedSidebarItem: \(selectedSidebarItem?.userInfo ?? [String: String]())\nsmartFeedsHidingReadArticles: \(smartFeedsHidingReadArticles)\nfeedsHidingReadArticles: \(feedsHidingReadArticles)\nfoldersShowingReadArticles: \(foldersShowingReadArticles)\nselectedArticle: \(selectedArticle?.dictionary ?? [String: String]())\narticleWindowScrollY: \(articleWindowScrollY)\nisShowingExtractedArticle: \(isShowingExtractedArticle ? "true" : "false")")
	}

	init() {
		self.init(hideReadFeeds: AppDefaults.hideReadFeeds,
				  expandedContainers: AppDefaults.expandedContainers,
				  selectedSidebarItem: AppDefaults.selectedSidebarItem,
				  smartFeedsHidingReadArticles: AppDefaults.smartFeedsHidingReadArticles,
				  feedsHidingReadArticles: AppDefaults.feedsHidingReadArticles,
				  foldersShowingReadArticles: AppDefaults.foldersShowingReadArticles,
				  selectedArticle: AppDefaults.selectedArticle,
				  articleWindowScrollY: AppDefaults.articleWindowScrollY,
				  isShowingExtractedArticle: AppDefaults.isShowingExtractedArticle)
	}

	// TODO: Delete for NetNewsWire 7.1.
	init(legacyState: NSUserActivity?) {
		if AppDefaults.didMigrateLegacyStateRestorationInfo {
			self.init()
			return
		}

		AppDefaults.didMigrateLegacyStateRestorationInfo = true

		// Extract legacy window state if available
		guard let windowState = legacyState?.userInfo?[UserInfoKey.windowState] as? [AnyHashable: Any] else {
			self.init()
			return
		}

		let hideReadFeeds: Bool
		if let legacyValue = windowState[UserInfoKey.readFeedsFilterState] as? Bool {
			hideReadFeeds = legacyValue
		} else {
			hideReadFeeds = AppDefaults.hideReadFeeds
		}

		let expandedContainers: Set<ContainerIdentifier>
		if let legacyState = windowState[UserInfoKey.containerExpandedWindowState] as? [[AnyHashable: AnyHashable]] {
			let convertedState = legacyState.compactMap { dict -> [String: String]? in
				var stringDict = [String: String]()
				for (key, value) in dict {
					if let keyString = key as? String, let valueString = value as? String {
						stringDict[keyString] = valueString
					}
				}
				return stringDict.isEmpty ? nil : stringDict
			}
			let containerIdentifiers = convertedState.compactMap { ContainerIdentifier(userInfo: $0) }
			expandedContainers = Set(containerIdentifiers)
		} else {
			expandedContainers = AppDefaults.expandedContainers
		}

		let sidebarItemsHidingReadArticles: Set<SidebarItemIdentifier>
		if let legacyState = windowState[UserInfoKey.readArticlesFilterState] as? [[AnyHashable: AnyHashable]: Bool] {
			let enabledFeeds = legacyState.filter { $0.value == true }
			let convertedState = enabledFeeds.keys.compactMap { key -> [String: String]? in
				var stringDict = [String: String]()
				for (k, v) in key {
					if let keyString = k as? String, let valueString = v as? String {
						stringDict[keyString] = valueString
					}
				}
				return stringDict.isEmpty ? nil : stringDict
			}
			let sidebarItemIdentifiers = convertedState.compactMap { SidebarItemIdentifier(userInfo: $0) }
			sidebarItemsHidingReadArticles = Set(sidebarItemIdentifiers)
		} else {
			sidebarItemsHidingReadArticles = Set<SidebarItemIdentifier>()
		}

		var smartFeedsHidingReadArticles = Set<String>()
		var feedsHidingReadArticles = [String: Set<String>]()
		for sidebarItem in sidebarItemsHidingReadArticles {
			switch sidebarItem {
			case .smartFeed(let id):
				smartFeedsHidingReadArticles.insert(id)
			case .feed(let accountID, let feedID):
				var feedIDs = feedsHidingReadArticles[accountID] ?? Set<String>()
				feedIDs.insert(feedID)
				feedsHidingReadArticles[accountID] = feedIDs
			default:
				continue
			}
		}

		let selectedSidebarItem: SidebarItemIdentifier?
		if let legacyState = windowState[UserInfoKey.feedIdentifier] as? [String: String],
		   let sidebarItemIdentifier = SidebarItemIdentifier(userInfo: legacyState) {
			selectedSidebarItem = sidebarItemIdentifier
		} else {
			selectedSidebarItem = AppDefaults.selectedSidebarItem
		}

		self.init(hideReadFeeds: hideReadFeeds,
				  expandedContainers: expandedContainers,
				  selectedSidebarItem: selectedSidebarItem,
				  smartFeedsHidingReadArticles: smartFeedsHidingReadArticles,
				  feedsHidingReadArticles: feedsHidingReadArticles,
				  foldersShowingReadArticles: AppDefaults.foldersShowingReadArticles,
				  selectedArticle: AppDefaults.selectedArticle,
				  articleWindowScrollY: AppDefaults.articleWindowScrollY,
				  isShowingExtractedArticle: AppDefaults.isShowingExtractedArticle)
	}
}
