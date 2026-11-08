//
//  AppDefaults.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/22/26.
//

import Foundation
import Images

/// Settings common to Mac and iOS. Platform-specific settings are in extensions in AppDefaults+Mac.swift and AppDefaults+iOS.swift.
enum AppDefaults {

	static let defaultThemeName = "Default"

	struct Key {
		static let firstRunDate = "firstRunDate"
		static let timelineSortDirection = "timelineSortDirection"
		static let timelineGroupByFeed = "timelineGroupByFeed"
		static let addFeedAccountID = "addFeedAccountID"
		static let addFeedFolderName = "addFeedFolderName"
		static let addFolderAccountID = "addFolderAccountID"
		static let currentThemeName = "currentThemeName"
		static let articleContentJavascriptEnabled = "articleContentJavascriptEnabled"
		static let unreadCountDisplay = "unreadCountDisplay"
		static let timelineThumbnailsDisplay = "timelineThumbnailsDisplay"
		static let timelineFeedIconsDisplay = "timelineFeedIconsDisplay"
		static let userInterfaceColorPalette = "userInterfaceColorPalette"
		static let sidebarShowsIcons = "sidebarShowsIcons"
		static let sidebarTextSize = "sidebarTextSize"
		static let showTodayFeed = "showTodayFeed"
		static let showUnreadFeed = "showUnreadFeed"
		static let showStarredFeed = "showStarredFeed"
		static let timelineIconDimension = "timelineIconSize"
		static let timelineTextSize = "timelineTextSize"
		static let timelineNumberOfLines = "timelineNumberOfLines"
		static let timelineShowFullTitles = "timelineShowFullTitles"
		static let timelineFadeReadArticles = "timelineFadeReadArticles"
		static let timelineFeedNameAndDateAboveTitle = "timelineFeedNameAndDateAboveTitle"
	}

	/// Registered by both platforms. Each platform’s registerDefaults adds its own.
	static var commonRegisteredDefaults: [String: Any] {
		[
			Key.timelineSortDirection: ComparisonResult.orderedDescending.rawValue,
			Key.timelineGroupByFeed: false,
			Key.currentThemeName: defaultThemeName,
			Key.articleContentJavascriptEnabled: true,
			Key.timelineThumbnailsDisplay: TimelineThumbnailsDisplay.none.rawValue,
			Key.timelineFeedIconsDisplay: TimelineFeedIconsDisplay.automatic.rawValue,
			Key.userInterfaceColorPalette: UserInterfaceColorPalette.automatic.rawValue,
			Key.sidebarShowsIcons: true,
			Key.sidebarTextSize: SidebarTextSize.system.rawValue,
			Key.showTodayFeed: true,
			Key.showUnreadFeed: true,
			Key.showStarredFeed: true,
			Key.timelineTextSize: TimelineTextSize.medium.rawValue,
			Key.timelineShowFullTitles: false,
			Key.timelineFadeReadArticles: false,
			Key.timelineFeedNameAndDateAboveTitle: false
		]
	}

	static let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()

	static let isFirstRun: Bool = {
		if UserDefaults.standard.object(forKey: Key.firstRunDate) is Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()

	static var addFeedAccountID: String? {
		get {
			UserDefaults.standard.string(forKey: Key.addFeedAccountID)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.addFeedAccountID)
		}
	}

	static var addFeedFolderName: String? {
		get {
			UserDefaults.standard.string(forKey: Key.addFeedFolderName)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.addFeedFolderName)
		}
	}

	static var addFolderAccountID: String? {
		get {
			UserDefaults.standard.string(forKey: Key.addFolderAccountID)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.addFolderAccountID)
		}
	}

	static var currentThemeName: String? {
		get {
			UserDefaults.standard.string(forKey: Key.currentThemeName)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.currentThemeName)
		}
	}

	static var isArticleContentJavascriptEnabled: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.articleContentJavascriptEnabled)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.articleContentJavascriptEnabled)
		}
	}

	static var unreadCountDisplay: UnreadCountDisplay {
		get {
			UnreadCountDisplay(rawValue: UserDefaults.standard.integer(forKey: Key.unreadCountDisplay)) ?? .count
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.unreadCountDisplay)
			NotificationCenter.default.post(name: .unreadCountDisplaySettingDidChange, object: nil)
		}
	}

	static var timelineThumbnailsDisplay: TimelineThumbnailsDisplay {
		get {
			TimelineThumbnailsDisplay(rawValue: UserDefaults.standard.integer(forKey: Key.timelineThumbnailsDisplay)) ?? .none
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.timelineThumbnailsDisplay)
			NotificationCenter.default.post(name: .timelineThumbnailsDisplayDidChange, object: nil)
		}
	}

	static var timelineFeedIconsDisplay: TimelineFeedIconsDisplay {
		get {
			TimelineFeedIconsDisplay(rawValue: UserDefaults.standard.integer(forKey: Key.timelineFeedIconsDisplay)) ?? .automatic
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.timelineFeedIconsDisplay)
			NotificationCenter.default.post(name: .timelineFeedIconsDisplayDidChange, object: nil)
		}
	}

	static var userInterfaceColorPalette: UserInterfaceColorPalette {
		get {
			UserInterfaceColorPalette(rawValue: UserDefaults.standard.integer(forKey: Key.userInterfaceColorPalette)) ?? .automatic
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.userInterfaceColorPalette)
			NotificationCenter.default.post(name: .userInterfaceColorPaletteDidUpdate, object: nil)
		}
	}

	static var sidebarShowsIcons: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.sidebarShowsIcons)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.sidebarShowsIcons)
			NotificationCenter.default.post(name: .sidebarShowsIconsDidChange, object: nil)
		}
	}

	static var sidebarTextSize: SidebarTextSize {
		get {
			SidebarTextSize(rawValue: UserDefaults.standard.integer(forKey: Key.sidebarTextSize)) ?? .system
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.sidebarTextSize)
			NotificationCenter.default.post(name: .sidebarTextSizeDidChange, object: nil)
		}
	}

	static var showTodayFeed: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.showTodayFeed)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.showTodayFeed)
			NotificationCenter.default.post(name: .sidebarSmartFeedsVisibilityDidChange, object: nil)
		}
	}

	static var showUnreadFeed: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.showUnreadFeed)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.showUnreadFeed)
			NotificationCenter.default.post(name: .sidebarSmartFeedsVisibilityDidChange, object: nil)
		}
	}

	static var showStarredFeed: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.showStarredFeed)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.showStarredFeed)
			NotificationCenter.default.post(name: .sidebarSmartFeedsVisibilityDidChange, object: nil)
		}
	}

	/// Registered per platform: iOS defaults to medium, Mac to large.
	static var timelineIconSize: IconSize {
		get {
			IconSize(rawValue: UserDefaults.standard.integer(forKey: Key.timelineIconDimension)) ?? .medium
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.timelineIconDimension)
			NotificationCenter.default.post(name: .timelineIconSizeDidChange, object: nil)
		}
	}

	static var timelineTextSize: TimelineTextSize {
		get {
			TimelineTextSize(rawValue: UserDefaults.standard.integer(forKey: Key.timelineTextSize)) ?? .medium
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: Key.timelineTextSize)
			NotificationCenter.default.post(name: .timelineTextSizeDidChange, object: nil)
		}
	}

	/// Lines shared by the title and summary. Registered per platform: iOS defaults to 2, Mac to 3.
	static var timelineNumberOfLines: Int {
		get {
			UserDefaults.standard.integer(forKey: Key.timelineNumberOfLines)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.timelineNumberOfLines)
			NotificationCenter.default.post(name: .timelineNumberOfLinesDidChange, object: nil)
		}
	}

	/// The whole title and no summary, instead of `timelineNumberOfLines` shared by both.
	static var timelineShowFullTitles: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.timelineShowFullTitles)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.timelineShowFullTitles)
			NotificationCenter.default.post(name: .timelineShowFullTitlesDidChange, object: nil)
		}
	}

	static var timelineFadeReadArticles: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.timelineFadeReadArticles)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.timelineFadeReadArticles)
			NotificationCenter.default.post(name: .timelineFadeReadArticlesDidChange, object: nil)
		}
	}

	/// The feed name (or author) and date line goes above the title instead of below the text.
	static var timelineFeedNameAndDateAboveTitle: Bool {
		get {
			UserDefaults.standard.bool(forKey: Key.timelineFeedNameAndDateAboveTitle)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.timelineFeedNameAndDateAboveTitle)
			NotificationCenter.default.post(name: .timelineFeedNameAndDateAboveTitleDidChange, object: nil)
		}
	}
}

// MARK: - Helpers

extension AppDefaults {

	static func date(for key: String) -> Date? {
		UserDefaults.standard.object(forKey: key) as? Date
	}

	static func setDate(for key: String, _ date: Date?) {
		UserDefaults.standard.set(date, forKey: key)
	}

	static func sortDirection(for key: String) -> ComparisonResult {
		let rawInt = UserDefaults.standard.integer(forKey: key)
		if rawInt == ComparisonResult.orderedAscending.rawValue {
			return .orderedAscending
		}
		return .orderedDescending
	}
}

private extension AppDefaults {

	static var firstRunDate: Date? {
		get {
			date(for: Key.firstRunDate)
		}
		set {
			setDate(for: Key.firstRunDate, newValue)
		}
	}
}
