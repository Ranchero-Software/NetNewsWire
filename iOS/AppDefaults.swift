//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/22/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import UIKit

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

final class AppDefaults {

	static let defaultThemeName = "Default"

	static let shared = AppDefaults()
	private init() {}

	static var store: UserDefaults = {
		let appIdentifierPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as! String
		let suiteName = "\(appIdentifierPrefix)group.\(Bundle.main.bundleIdentifier!)"
		return UserDefaults.init(suiteName: suiteName)!
	}()

	let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()

	let isFirstRun: Bool = {
		if AppDefaults.store.object(forKey: AppDefaultsKey.firstRunDate) as? Date == nil {
			firstRunDate = Date()
			return true
		}
		return false
	}()

	static var userInterfaceColorPalette: UserInterfaceColorPalette {
		get {
			if let result = UserInterfaceColorPalette(rawValue: int(for: AppDefaultsKey.userInterfaceColorPalette)) {
				return result
			}
			return .automatic
		}
		set {
			setInt(for: AppDefaultsKey.userInterfaceColorPalette, newValue.rawValue)
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

	var useSystemBrowser: Bool {
		get {
			return UserDefaults.standard.bool(forKey: AppDefaultsKey.useSystemBrowser)
		}
		set {
			UserDefaults.standard.setValue(newValue, forKey: AppDefaultsKey.useSystemBrowser)
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

	var timelineGroupByFeed: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.timelineGroupByFeed)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.timelineGroupByFeed, newValue)
		}
	}

	var refreshClearsReadArticles: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.refreshClearsReadArticles)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.refreshClearsReadArticles, newValue)
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

	var articleFullscreenAvailable: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.articleFullscreenAvailable)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.articleFullscreenAvailable, newValue)
		}
	}

	var articleFullscreenEnabled: Bool {
		get {
			return articleFullscreenAvailable && AppDefaults.bool(for: AppDefaultsKey.articleFullscreenEnabled)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.articleFullscreenEnabled, newValue)
		}
	}

	var logicalArticleFullscreenEnabled: Bool {
		articleFullscreenAvailable && articleFullscreenEnabled
	}

	var confirmMarkAllAsRead: Bool {
		get {
			return AppDefaults.bool(for: AppDefaultsKey.confirmMarkAllAsRead)
		}
		set {
			AppDefaults.setBool(for: AppDefaultsKey.confirmMarkAllAsRead, newValue)
		}
	}

	var lastRefresh: Date? {
		get {
			return AppDefaults.date(for: AppDefaultsKey.lastRefresh)
		}
		set {
			AppDefaults.setDate(for: AppDefaultsKey.lastRefresh, newValue)
		}
	}

	var timelineNumberOfLines: Int {
		get {
			return AppDefaults.int(for: AppDefaultsKey.timelineNumberOfLines)
		}
		set {
			AppDefaults.setInt(for: AppDefaultsKey.timelineNumberOfLines, newValue)
		}
	}

	var timelineIconSize: IconSize {
		get {
			let rawValue = AppDefaults.store.integer(forKey: AppDefaultsKey.timelineIconDimension)
			return IconSize(rawValue: rawValue) ?? IconSize.medium
		}
		set {
			AppDefaults.store.set(newValue.rawValue, forKey: AppDefaultsKey.timelineIconDimension)
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

	var isArticleContentJavascriptEnabled: Bool {
		get {
			UserDefaults.standard.bool(forKey: AppDefaultsKey.articleContentJavascriptEnabled)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: AppDefaultsKey.articleContentJavascriptEnabled)
		}
	}

	static func registerDefaults() {
		let defaults: [String: Any] = [AppDefaultsKey.userInterfaceColorPalette: UserInterfaceColorPalette.automatic.rawValue,
									   AppDefaultsKey.timelineGroupByFeed: false,
									   AppDefaultsKey.refreshClearsReadArticles: false,
									   AppDefaultsKey.timelineNumberOfLines: 2,
									   AppDefaultsKey.timelineIconDimension: IconSize.medium.rawValue,
									   AppDefaultsKey.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
									   AppDefaultsKey.articleFullscreenAvailable: false,
									   AppDefaultsKey.articleFullscreenEnabled: false,
									   AppDefaultsKey.confirmMarkAllAsRead: true,
									   AppDefaultsKey.currentThemeName: Self.defaultThemeName]
		AppDefaults.store.register(defaults: defaults)
	}

}

private extension AppDefaults {

	static var firstRunDate: Date? {
		get {
			return date(for: AppDefaultsKey.firstRunDate)
		}
		set {
			setDate(for: AppDefaultsKey.firstRunDate, newValue)
		}
	}

	static func string(for key: String) -> String? {
		return UserDefaults.standard.string(forKey: key)
	}

	static func setString(for key: String, _ value: String?) {
		UserDefaults.standard.set(value, forKey: key)
	}

	static func bool(for key: String) -> Bool {
		return AppDefaults.store.bool(forKey: key)
	}

	static func setBool(for key: String, _ flag: Bool) {
		AppDefaults.store.set(flag, forKey: key)
	}

	static func int(for key: String) -> Int {
		return AppDefaults.store.integer(forKey: key)
	}

	static func setInt(for key: String, _ x: Int) {
		AppDefaults.store.set(x, forKey: key)
	}

	static func date(for key: String) -> Date? {
		return AppDefaults.store.object(forKey: key) as? Date
	}

	static func setDate(for key: String, _ date: Date?) {
		AppDefaults.store.set(date, forKey: key)
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
