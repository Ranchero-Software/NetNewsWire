//
//  AppDelegate+Shared.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/15/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation
import Images
import ParserObjC
import Account

extension AppDelegate: FaviconDownloaderDelegate, FeedIconDownloaderDelegate {

	var appIconImage: IconImage? {
		IconImage.appIcon
	}

	func downloadMetadata(_ url: String) async throws -> RSHTMLMetadata? {

		await HTMLMetadataDownloader.downloadMetadata(for: url)
	}

	func initializeDownloaders() {

		FaviconDownloader.shared.delegate = self
		FeedIconDownloader.shared.delegate = self
	}

	func handleUnreadCountDidChange() {
		
		AppNotification.postAppUnreadCountDidChange(from: self, unreadCount: unreadCount)
		postUnreadCountDidChangeNotification()
		updateBadge()
	}

	func updateBadge() {

#if os(macOS)
		queueUpdateDockBadge()
#elseif os(iOS)
		UNUserNotificationCenter.current().setBadgeCount(unreadCount)
#endif
	}

	func importFeedsIfNeeded() {

		guard AppDefaults.shared.isFirstRun else {
			return
		}
		guard !AccountManager.shared.anyAccountHasAtLeastOneFeed() else {
			return
		}

		let localAccount = AccountManager.shared.defaultAccount

#if os(macOS)
		// Import feeds. Either old NNW 3 feeds or the default feeds.
		if !NNW3ImportController.importSubscriptionsIfFileExists(account: localAccount) {
			DefaultFeedsImporter.importDefaultFeeds(account: localAccount)
		}
#elseif os(iOS)
		DefaultFeedsImporter.importDefaultFeeds(account: localAccount)
#endif
	}
}
