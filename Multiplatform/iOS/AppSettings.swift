//
//  AppSettings.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 1/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum ColorPalette: Int, CustomStringConvertible, CaseIterable {
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


class AppSettings: ObservableObject {
	
	struct Key {
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
	
	static let isDeveloperBuild: Bool = {
		if let dev = Bundle.main.object(forInfoDictionaryKey: "DeveloperEntitlements") as? String, dev == "-dev" {
			return true
		}
		return false
	}()

	static let isFirstRun: Bool = {
		if let _ = AppDefaults.shared.object(forKey: Key.firstRunDate) as? Date {
			return false
		}
		firstRunDate = Date()
		return true
	}()
	
	
	
	
	
	
	
	
}
