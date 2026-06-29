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
	private var cache = [Feed: IconImage]()
	private var waitingForFeedURLs = [String: Feed]()

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .imageDidBecomeAvailable, object: imageDownloader)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		cache.removeAll()
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		cache.removeAll()
	}

	public func icon(for feed: Feed) -> IconImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}

		if Self.shouldSkipDownloadingFeedIcon(feed: feed) {
			return nil
		}

		@MainActor func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}
			if homePagesWithNoIconURL.contains(homePageURL) {
				return
			}
			icon(forHomePageURL: homePageURL, feed: feed) { image, iconURL in
				if self.cache[feed] != nil {
					return // already cached
				}
				if let image, let iconURL {
					self.cache[feed] = IconImage(image)
					self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
					self.postFeedIconDidBecomeAvailableNotification(feed)
				}
			}
		}

		@MainActor func checkFeedIconURL() {
			if let iconURL = feed.iconURL, !Self.shouldIgnoreFeedIconURL(feed) {
				icon(forURL: iconURL, feed: feed) { (image) in
					Task { @MainActor in
						if self.cache[feed] != nil {
							return // already cached
						}
						if let image = image {
							self.cache[feed] = IconImage(image)
							self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
							self.postFeedIconDidBecomeAvailableNotification(feed)
						} else {
							checkHomePageURL()
						}
					}
				}
			} else {
				checkHomePageURL()
			}
		}

		if let previouslyFoundIconURL = ImageMetadataDatabase.shared.iconURL(forFeedURL: feed.url) {
			icon(forURL: previouslyFoundIconURL, feed: feed) { image in
				MainActor.assumeIsolated {
					if self.cache[feed] != nil {
						return // already cached
					}
					if let image {
						self.cache[feed] = IconImage(image)
						self.postFeedIconDidBecomeAvailableNotification(feed)
					}
				}
			}

			return nil
		}

		checkFeedIconURL()

		return nil
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		guard let url = note.userInfo?["url"] as? String, let feed = waitingForFeedURLs[url] else {
			return
		}
		waitingForFeedURLs[url] = nil
		_ = icon(for: feed)
	}

	/// Returns the in-memory icon for `feed` without triggering a download.
	public func cachedIcon(for feed: Feed) -> IconImage? {
		cache[feed]
	}
}

private extension FeedIconDownloader {

	static let specialCasesToSkip = ["macsparky.com", "xkcd.com", SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]

	// Substrings matched (case-insensitive) anywhere in the feed URL. A match makes us ignore the
	// feed-specified icon URL and fall back to the homepage icon lookup instead.
	static let feedURLSubstringsToIgnoreFeedIconURL: [String] = ["propublica.org", "clubic.com", "comptoir-hardware.com", "cowcotland", "404media.co", "awfulannouncing.com", "michalzelazny.com"]

	static func shouldIgnoreFeedIconURL(_ feed: Feed) -> Bool {
		SpecialCase.urlStringContainSpecialCase(feed.url, feedURLSubstringsToIgnoreFeedIconURL)
	}

	static func shouldSkipDownloadingFeedIcon(feed: Feed) -> Bool {
		shouldSkipDownloadingFeedIcon(feed.url)
	}

	static func shouldSkipDownloadingFeedIcon(_ urlString: String) -> Bool {
		SpecialCase.urlStringContainSpecialCase(urlString, specialCasesToSkip)
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

	func icon(forHomePageURL homePageURL: String, feed: Feed, _ resultBlock: @escaping @MainActor (RSImage?, String?) -> Void) {
		if Self.shouldSkipDownloadingFeedIcon(homePageURL) {
			resultBlock(nil, nil)
			return
		}

		if homePagesWithNoIconURL.contains(homePageURL) {
			resultBlock(nil, nil)
			return
		}

		guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			resultBlock(nil, nil)
			return
		}

		if let url = metadata.bestWebsiteIconURL() {
			homePagesWithNoIconURL.remove(homePageURL)
			icon(forURL: url, feed: feed) { image in
				Task { @MainActor in
					resultBlock(image, url)
				}
			}
			return
		}

		homePagesWithNoIconURL.insert(homePageURL)
		resultBlock(nil, nil)
	}

	func icon(forURL url: String, feed: Feed, _ imageResultBlock: @escaping ImageResultBlock) {

		let url = Self.sanitizedIconURL(url)

		let kind = ActivityKind.downloadFeedImage(feedURL: url)
		if let imageData = imageDownloader.image(for: url, activityOwner: .feedImageDownloader, activityKind: kind, activityDetail: feed.nameForDisplay) {
			RSImage.image(with: imageData, imageResultBlock: imageResultBlock)
			return
		}

		waitingForFeedURLs[url] = feed
		imageResultBlock(nil)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: Feed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = ["feed": feed]
			NotificationCenter.default.post(name: .feedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func cacheIconURLForFeedURL(iconURL: String, feedURL: String) {
		ImageMetadataDatabase.shared.saveFeedIconURL(feedURL: feedURL, iconURL: iconURL)
	}
}
