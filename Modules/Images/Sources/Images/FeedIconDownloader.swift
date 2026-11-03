//
//  FeedIconDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore
import RSWeb
import ActivityLog

extension Notification.Name {
	/// Posted when a feed’s icon loads or fails, or its icon URL changes.
	/// userInfo key: `FeedIconDownloader.feedKey`.
	public static let feedIconDidChange = Notification.Name("FeedIconDidChange")
}

/// Gets the icon a feed specifies in the feed itself.
@MainActor public final class FeedIconDownloader {

	public static let shared = FeedIconDownloader()
	public static let feedKey = "feed"

	private var feedsByIconURL = [String: Set<Feed>]() // icon URL: feeds that looked it up

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleIconImageDidBecomeAvailable(_:)), name: .iconImageDidBecomeAvailable, object: IconImageDownloader.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleIconImageDownloadDidFail(_:)), name: .iconImageDownloadDidFail, object: IconImageDownloader.shared)
		NotificationCenter.default.addObserver(self, selector: #selector(handleFeedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)
	}

	/// Unavailable when the feed specifies no icon, or its icon isn’t used.
	public func feedIcon(for feed: Feed) -> IconLookup {
		guard let iconURL = Self.iconURL(for: feed) else {
			return .unavailable
		}
		feedsByIconURL[iconURL, default: Set<Feed>()].insert(feed)
		return IconImageDownloader.shared.iconImage(for: iconURL, activityOwner: .feedImageDownloader, activityKind: .downloadFeedImage(feedURL: iconURL), activityDetail: feed.nameForDisplay)
	}

	// MARK: - Notifications

	@objc func handleIconImageDidBecomeAvailable(_ notification: Notification) {
		postFeedIconDidChange(iconURL: notification.userInfo?[IconImageDownloader.urlKey] as? String)
	}

	@objc func handleIconImageDownloadDidFail(_ notification: Notification) {
		postFeedIconDidChange(iconURL: notification.userInfo?[IconImageDownloader.urlKey] as? String)
	}

	@objc func handleFeedSettingDidChange(_ notification: Notification) {
		guard let feed = notification.object as? Feed, let key = notification.userInfo?[Feed.SettingUserInfoKey] as? Feed.SettingKey, key == .iconURL else {
			return
		}
		postFeedIconDidChange(feed)
	}
}

private extension FeedIconDownloader {

	// Substrings matched (case-insensitive) anywhere in the feed URL. A match means the feed-specified icon isn’t used.
	static let feedURLSubstringsToIgnoreFeedIconURL: [String] = ["propublica.org", "clubic.com", "comptoir-hardware.com", "cowcotland", "404media.co", "awfulannouncing.com", "michalzelazny.com"]

	static func iconURL(for feed: Feed) -> String? {
		guard let iconURL = feed.iconURL else {
			return nil
		}
		if SpecialCase.urlStringContainSpecialCase(feed.url, SpecialCase.hostNamesWithoutFeedOrHomePageIcons) || SpecialCase.urlStringContainSpecialCase(feed.url, feedURLSubstringsToIgnoreFeedIconURL) {
			return nil
		}
		return sanitizedIconURL(iconURL)
	}

	static func sanitizedIconURL(_ url: String) -> String {
		// WordPress URLs with /wp-content/uploads/ often have query params
		// that specify a small size (32x32). Drop the query params to get a larger image.
		guard url.contains("/wp-content/uploads/") else {
			return url
		}
		guard var components = URLComponents(string: url) else {
			return url
		}
		components.query = nil
		components.fragment = nil
		return components.string ?? url
	}

	func postFeedIconDidChange(iconURL: String?) {
		guard let iconURL, let feeds = feedsByIconURL[iconURL] else {
			return
		}
		for feed in feeds {
			postFeedIconDidChange(feed)
		}
	}

	func postFeedIconDidChange(_ feed: Feed) {
		NotificationCenter.default.post(name: .feedIconDidChange, object: self, userInfo: [Self.feedKey: feed])
	}
}
