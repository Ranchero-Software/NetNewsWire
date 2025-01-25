//
//  AppDefaultsKey.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/25/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

struct AppDefaultsKey {

	static let firstRunDate = "firstRunDate"
	static let lastImageCacheFlushDate = "lastImageCacheFlushDate"
	static let timelineGroupByFeed = "timelineGroupByFeed"
	static let timelineSortDirection = "timelineSortDirection"
	static let addFeedAccountID = "addFeedAccountID"
	static let addFeedFolderName = "addFeedFolderName"
	static let addFolderAccountID = "addFolderAccountID"
	static let currentThemeName = "currentThemeName"
	static let articleContentJavascriptEnabled = "articleContentJavascriptEnabled"

#if os(macOS)

	static let windowState = "windowState"
	static let sidebarFontSize = "sidebarFontSize"
	static let timelineFontSize = "timelineFontSize"
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

#elseif os(iOS)

	static let userInterfaceColorPalette = "userInterfaceColorPalette"
	static let refreshClearsReadArticles = "refreshClearsReadArticles"
	static let timelineNumberOfLines = "timelineNumberOfLines"
	static let timelineIconDimension = "timelineIconSize"
	static let articleFullscreenAvailable = "articleFullscreenAvailable"
	static let articleFullscreenEnabled = "articleFullscreenEnabled"
	static let confirmMarkAllAsRead = "confirmMarkAllAsRead"
	static let lastRefresh = "lastRefresh"
	static let useSystemBrowser = "useSystemBrowser"

#endif
}
