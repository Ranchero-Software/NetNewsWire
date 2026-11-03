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
import HTMLMetadata
import ActivityLog

extension Notification.Name {

	public static let feedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailable") // userInfo key: "feed"
}

@MainActor public final class FeedIconDownloader {

	public static let shared = FeedIconDownloader()

	private let imageDownloader = ImageDownloader.shared
	private var homePagesWithNoIconURL = Set<String>()
	private var cache = [Feed: CachedIcon]()
	private var waitingForFeedURLs = [String: Set<Feed>]()
	private var feedsWaitingForHTMLMetadata = Set<Feed>()
	private var iconDecodeTasks = [String: Task<IconImage?, Never>]() // sanitized icon URL: its one decode

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .imageDidBecomeAvailable, object: imageDownloader)
		NotificationCenter.default.addObserver(self, selector: #selector(handleImageDownloadDidFail(_:)), name: .imageDownloadDidFail, object: imageDownloader)
		NotificationCenter.default.addObserver(self, selector: #selector(handleDownloadedImageDidChange(_:)), name: .downloadedImageDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleFeedSettingDidChange(_:)), name: .feedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleHTMLMetadataAvailable(_:)), name: .htmlMetadataAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusDidChange(_:)), name: .networkStatusDidChange, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		cache.removeAll()
		iconDecodeTasks.removeAll()
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		cache.removeAll()
		iconDecodeTasks.removeAll()
	}

	public func icon(for feed: Feed) -> IconImage? {

		if let cachedIcon = cache[feed] {
			requestOwnIconIfRetryWaitEnded(feed)
			return cachedIcon.iconImage
		}

		if Self.shouldSkipDownloadingFeedIcon(feed: feed) {
			return nil
		}

		@MainActor func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}
			icon(forHomePageURL: homePageURL, feed: feed) { iconImage, iconURL in
				if let iconImage, let iconURL, self.cacheIcon(iconImage, for: feed, isFeedOwnIcon: false) {
					self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
					self.postFeedIconDidBecomeAvailableNotification(feed)
				}
			}
		}

		@MainActor func checkSavedHomePageIconURL(_ savedIconURL: String) {
			icon(forURL: savedIconURL, feed: feed) { iconImage, isDefinitive in
				if let iconImage {
					if self.cacheIcon(iconImage, for: feed, isFeedOwnIcon: false) {
						self.postFeedIconDidBecomeAvailableNotification(feed)
					}
				} else if self.cache[feed] == nil, isDefinitive {
					// The site may have moved its icon, so the home page is checked again.
					checkHomePageURL()
				}
			}
		}

		@MainActor func checkFeedIconURL() {
			if let iconURL = feed.iconURL, !Self.shouldIgnoreFeedIconURL(feed) {
				icon(forURL: iconURL, feed: feed) { (iconImage, isDefinitive) in
					Task { @MainActor in
						if let iconImage {
							if self.cacheIcon(iconImage, for: feed, isFeedOwnIcon: true) {
								self.postFeedIconDidBecomeAvailableNotification(feed)
							}
						} else if self.cache[feed] == nil, isDefinitive {
							// The declared icon failed or isn’t an image. A still-downloading
							// icon is no reason to fall back to the home page’s icon.
							// <https://github.com/Ranchero-Software/NetNewsWire/issues/5376>
							// A home page icon found earlier works without the home page’s metadata.
							if let savedIconURL = ImageDatabase.shared.iconURL(forFeedURL: feed.url) {
								checkSavedHomePageIconURL(savedIconURL)
							} else {
								checkHomePageURL()
							}
						}
					}
				}
			} else {
				checkHomePageURL()
			}
		}

		if let previouslyFoundIconURL = Self.savedHomePageIconURL(for: feed) {
			checkSavedHomePageIconURL(previouslyFoundIconURL)
			checkForNewHomePageIconURL(feed, savedIconURL: previouslyFoundIconURL)

			return nil
		}

		checkFeedIconURL()

		return nil
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		guard let url = note.userInfo?["url"] as? String, let feeds = waitingForFeedURLs[url] else {
			return
		}
		// A single image URL may be shared by multiple feeds.
		waitingForFeedURLs[url] = nil
		for feed in feeds {
			// A waiting feed with an icon is showing its home page icon until its own arrives.
			cache[feed] = nil
			_ = icon(for: feed)
		}
	}

	/// Waits for transient failures may have just ended, so waiting icons are requested again.
	/// Runs after `DownloadedImageCache` ends those waits, which it does on this notification too.
	@objc func handleNetworkStatusDidChange(_ notification: Notification) {
		guard NetworkMonitor.shared.isConnected else {
			return
		}
		Task { @MainActor in
			for (url, feeds) in waitingForFeedURLs where !DownloadedImageCache.shared.isWaitingToRetry(url) {
				_ = imageData(for: url, feed: feeds.first)
			}
		}
	}

	/// Feeds waiting on the failed URL look again, which falls back to the home page icon.
	@objc func handleImageDownloadDidFail(_ notification: Notification) {
		guard let url = notification.userInfo?["url"] as? String, let feeds = waitingForFeedURLs[url] else {
			return
		}
		waitingForFeedURLs[url] = nil
		for feed in feeds {
			cache[feed] = nil
			_ = icon(for: feed)
		}
	}

	/// `ImageDownloader` makes the image again, and feeds using it get their icon again when it’s ready.
	@objc func handleDownloadedImageDidChange(_ notification: Notification) {
		guard let url = notification.userInfo?[DownloadedImageCache.urlKey] as? String else {
			return
		}
		iconDecodeTasks[url] = nil
		let feeds = cache.keys.filter { Self.iconURLs(for: $0).contains(url) }
		for feed in feeds {
			cache[feed] = nil
			waitingForFeedURLs[url, default: Set<Feed>()].insert(feed)
		}
	}

	@objc func handleFeedSettingDidChange(_ note: Notification) {
		guard let feed = note.object as? Feed, let key = note.userInfo?[Feed.SettingUserInfoKey] as? Feed.SettingKey else {
			return
		}
		if key == .iconURL || key == .homePageURL {
			// `IconImageCache` keeps showing the old icon until the new one is ready.
			cache[feed] = nil
			_ = icon(for: feed)
		}
	}

	@objc func handleHTMLMetadataAvailable(_ note: Notification) {
		guard let url = note.userInfo?[HTMLMetadataUserInfoKey.url] as? String else {
			return
		}
		homePagesWithNoIconURL.remove(url)
		// A homepage URL may be shared by multiple feeds.
		let feeds = feedsWaitingForHTMLMetadata.filter { $0.homePageURL == url }
		feedsWaitingForHTMLMetadata.subtract(feeds)
		for feed in feeds {
			// A feed already showing its saved home page icon would return it without checking.
			if cache[feed] != nil, let savedIconURL = Self.savedHomePageIconURL(for: feed) {
				checkForNewHomePageIconURL(feed, savedIconURL: savedIconURL)
			} else {
				_ = icon(for: feed)
			}
		}
	}
}

private extension FeedIconDownloader {

	struct CachedIcon {
		let iconImage: IconImage
		let isFeedOwnIcon: Bool
	}

	/// The feed’s own icon replaces its home page icon, but a home page icon never replaces the feed’s own.
	func cacheIcon(_ iconImage: IconImage, for feed: Feed, isFeedOwnIcon: Bool) -> Bool {
		if let cachedIcon = cache[feed], cachedIcon.isFeedOwnIcon || !isFeedOwnIcon {
			return false
		}
		cache[feed] = CachedIcon(iconImage: iconImage, isFeedOwnIcon: isFeedOwnIcon)
		return true
	}

	static let specialCasesToSkip = ["macsparky.com", "xkcd.com", SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]

	// Substrings matched (case-insensitive) anywhere in the feed URL. A match makes us ignore the
	// feed-specified icon URL and fall back to the homepage icon lookup instead.
	static let feedURLSubstringsToIgnoreFeedIconURL: [String] = ["propublica.org", "clubic.com", "comptoir-hardware.com", "cowcotland", "404media.co", "awfulannouncing.com", "michalzelazny.com"]

	static func shouldIgnoreFeedIconURL(_ feed: Feed) -> Bool {
		SpecialCase.urlStringContainSpecialCase(feed.url, feedURLSubstringsToIgnoreFeedIconURL)
	}

	/// The stored icon URL remembers an icon discovered via the home page. A feed
	/// that declares its own icon supersedes it.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/5376>
	static func savedHomePageIconURL(for feed: Feed) -> String? {
		let feedDeclaresIconURL = feed.iconURL != nil && !shouldIgnoreFeedIconURL(feed)
		if feedDeclaresIconURL {
			return nil
		}
		return ImageDatabase.shared.iconURL(forFeedURL: feed.url)
	}

	/// The saved icon keeps working after a site adds a better icon or moves to a new one,
	/// so the home page’s metadata is checked too. A different best icon replaces the saved one once it’s ready.
	func checkForNewHomePageIconURL(_ feed: Feed, savedIconURL: String) {
		guard let homePageURL = feed.homePageURL, !Self.shouldSkipDownloadingFeedIcon(homePageURL) else {
			return
		}
		guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			feedsWaitingForHTMLMetadata.insert(feed)
			return
		}
		guard let iconURL = metadata.bestWebsiteIconURL(), iconURL != savedIconURL else {
			return
		}
		icon(forURL: iconURL, feed: feed) { iconImage, _ in
			guard let iconImage else {
				return
			}
			// Replaces the saved home page icon, which `cacheIcon` wouldn’t.
			self.cache[feed] = CachedIcon(iconImage: iconImage, isFeedOwnIcon: false)
			self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
			self.postFeedIconDidBecomeAvailableNotification(feed)
		}
	}

	static func shouldSkipDownloadingFeedIcon(feed: Feed) -> Bool {
		shouldSkipDownloadingFeedIcon(feed.url)
	}

	static func shouldSkipDownloadingFeedIcon(_ urlString: String) -> Bool {
		SpecialCase.urlStringContainSpecialCase(urlString, specialCasesToSkip)
	}

	/// The URLs a feed’s icon may have been made from: its own icon URL and the one found on its home page.
	static func iconURLs(for feed: Feed) -> [String] {
		[feed.iconURL, ImageDatabase.shared.iconURL(forFeedURL: feed.url)].compactMap { $0 }.map(sanitizedIconURL)
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

	func icon(forHomePageURL homePageURL: String, feed: Feed, _ resultBlock: @escaping @MainActor (IconImage?, String?) -> Void) {
		if Self.shouldSkipDownloadingFeedIcon(homePageURL) {
			resultBlock(nil, nil)
			return
		}

		if homePagesWithNoIconURL.contains(homePageURL) {
			feedsWaitingForHTMLMetadata.insert(feed)
			resultBlock(nil, nil)
			return
		}

		guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			feedsWaitingForHTMLMetadata.insert(feed)
			resultBlock(nil, nil)
			return
		}

		if let url = metadata.bestWebsiteIconURL() {
			homePagesWithNoIconURL.remove(homePageURL)
			icon(forURL: url, feed: feed) { iconImage, _ in
				Task { @MainActor in
					resultBlock(iconImage, url)
				}
			}
			return
		}

		// The feed is checked again when the home page’s metadata refreshes.
		homePagesWithNoIconURL.insert(homePageURL)
		feedsWaitingForHTMLMetadata.insert(feed)
		resultBlock(nil, nil)
	}

	/// `isDefinitive` is false when the image is still downloading — imageDidBecomeAvailable
	/// re-runs icon(for:) when it arrives.
	///
	/// After a transient failure, `isDefinitive` is true, so the caller can fall back to the home page icon,
	/// and the feed still waits for this image, which replaces the fallback when it arrives.
	func icon(forURL url: String, feed: Feed, _ imageResultBlock: @escaping @MainActor (IconImage?, _ isDefinitive: Bool) -> Void) {

		let url = Self.sanitizedIconURL(url)

		if let imageData = imageData(for: url, feed: feed) {
			let decodeTask = iconDecodeTask(url: url, imageData: imageData)
			Task { @MainActor in
				imageResultBlock(await decodeTask.value, true)
			}
			return
		}

		let urlIsUnfetchable = !url.hasPrefix("http://") && !url.hasPrefix("https://")
		if urlIsUnfetchable || ImageDatabase.shared.recentlyFailed(url: url) {
			imageResultBlock(nil, true)
			return
		}

		waitingForFeedURLs[url, default: Set<Feed>()].insert(feed)
		imageResultBlock(nil, DownloadedImageCache.shared.isWaitingToRetry(url))
	}

	/// Feeds that share an icon URL share one decode and one bitmap.
	func iconDecodeTask(url: String, imageData: Data) -> Task<IconImage?, Never> {
		if let decodeTask = iconDecodeTasks[url] {
			return decodeTask
		}
		let decodeTask = Task {
			await IconImage.decodedIconImage(imageData)
		}
		iconDecodeTasks[url] = decodeTask
		return decodeTask
	}

	/// Returns the data if in memory, else requests it. `imageDidBecomeAvailable` follows when it’s ready.
	func imageData(for url: String, feed: Feed?) -> Data? {
		imageDownloader.image(for: url, activityOwner: .feedImageDownloader, activityKind: .downloadFeedImage(feedURL: url), activityDetail: feed?.nameForDisplay)
	}

	/// A feed showing its home page icon while it waits for its own requests it again once the retry wait ends.
	func requestOwnIconIfRetryWaitEnded(_ feed: Feed) {
		guard let iconURL = feed.iconURL, !Self.shouldIgnoreFeedIconURL(feed) else {
			return
		}
		let url = Self.sanitizedIconURL(iconURL)
		guard waitingForFeedURLs[url]?.contains(feed) == true, !DownloadedImageCache.shared.isWaitingToRetry(url) else {
			return
		}
		_ = imageData(for: url, feed: feed)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: Feed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = ["feed": feed]
			NotificationCenter.default.post(name: .feedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func cacheIconURLForFeedURL(iconURL: String, feedURL: String) {
		ImageDatabase.shared.saveFeedIconURL(feedURL: feedURL, iconURL: iconURL)
	}
}
