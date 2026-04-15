//
//  FeedIconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore
import RSWeb
import RSParser

extension Notification.Name {

	static let feedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailable") // UserInfoKey.feed
}

@MainActor public final class FeedIconDownloader {

	public static let shared = FeedIconDownloader()

	private let imageDownloader = ImageDownloader.shared
	private static let saveQueue = CoalescingQueue(name: "Cache Save Queue", interval: 1.0)
	private var homePagesWithNoIconURL = Set<String>()
	private var cache = [Feed: IconImage]()
	private var waitingForFeedURLs = [String: Feed]()

	private var feedURLToIconURLCache = [String: String]()
	private var feedURLToIconURLCachePath: URL
	private var feedURLToIconURLCacheDirty = false {
		didSet {
			queueSaveFeedURLToIconURLCacheIfNeeded()
		}
	}

	init() {

		let folder = AppConfig.cacheSubfolder(named: "FeedIcons")
		self.feedURLToIconURLCachePath = folder.appendingPathComponent("FeedURLToIconURLCache.plist")
		loadFeedURLToIconURLCache()

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

	func icon(for feed: Feed) -> IconImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}

		if let homePageURLString = feed.homePageURL, let homePageURL = URL(string: homePageURLString) {
			if homePageURL.host == "nnw.ranchero.com" || homePageURL.host == "netnewswire.blog" || homePageURL.host == "services.netnewswire.com" {
				return IconImage.nnwFeedIcon
			}
		}
		if feed.url.hasPrefix("https://ranchero.com/downloads/netnewswire") {
			return IconImage.nnwFeedIcon
		}

		if let knownIconURL = Self.knownIconURL(for: feed) {
			icon(forURL: knownIconURL, feed: feed) { image in
				MainActor.assumeIsolated {
					if self.cache[feed] != nil {
						return
					}
					if let image {
						self.cache[feed] = IconImage(image)
						self.postFeedIconDidBecomeAvailableNotification(feed)
					}
				}
			}
			return nil
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

		if let previouslyFoundIconURL = feedURLToIconURLCache[feed.url] {
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
		guard let url = note.userInfo?[UserInfoKey.url] as? String, let feed = waitingForFeedURLs[url] else {
			return
		}
		waitingForFeedURLs[url] = nil
		_ = icon(for: feed)
	}
}

private extension FeedIconDownloader {

	static let specialCasesToSkip = ["macsparky.com", "xkcd.com", SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]

	// Domains where the feed-specified icon URL should be ignored,
	// falling back to the homepage icon lookup instead.
	static let domainsToIgnoreFeedIconURL: [String] = ["stratechery.com", "propublica.org", "substack.com"]

	// Domains with a known-good icon URL to use instead of the
	// feed-specified icon or homepage lookup.
	static let domainToIconURL: [String: String] = [
		"github.blog": "https://github.blog/wp-content/uploads/2019/01/cropped-github-favicon-512.png",
		"github.com": "https://github.blog/wp-content/uploads/2019/01/cropped-github-favicon-512.png"
		]

	static func shouldSkipDownloadingFeedIcon(feed: Feed) -> Bool {
		shouldSkipDownloadingFeedIcon(feed.url)
	}

	static func shouldSkipDownloadingFeedIcon(_ urlString: String) -> Bool {
		SpecialCase.urlStringContainSpecialCase(urlString, specialCasesToSkip)
	}

	static func shouldIgnoreFeedIconURL(_ feed: Feed) -> Bool {
		guard !domainsToIgnoreFeedIconURL.isEmpty else {
			return false
		}
		return SpecialCase.urlStringContainSpecialCase(feed.url, domainsToIgnoreFeedIconURL)
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

	static func knownIconURL(for feed: Feed) -> String? {
		guard !domainToIconURL.isEmpty else {
			return nil
		}
		let lowerFeedURL = feed.url.lowercased(with: localeForLowercasing)
		for (domain, iconURL) in domainToIconURL {
			if lowerFeedURL.contains(domain) {
				return iconURL
			}
		}
		return nil
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
		waitingForFeedURLs[url] = feed
		guard let imageData = imageDownloader.image(for: url) else {
			imageResultBlock(nil)
			return
		}
		RSImage.image(with: imageData, imageResultBlock: imageResultBlock)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: Feed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.feed: feed]
			NotificationCenter.default.post(name: .feedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func cacheIconURLForFeedURL(iconURL: String, feedURL: String) {

		feedURLToIconURLCache[feedURL] = iconURL
		feedURLToIconURLCacheDirty = true
	}

	func loadFeedURLToIconURLCache() {

		guard let data = try? Data(contentsOf: feedURLToIconURLCachePath) else {
			return
		}
		let decoder = PropertyListDecoder()
		feedURLToIconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	@objc func saveFeedURLToIconURLCacheIfNeeded() {

		assert(Thread.isMainThread)
		if feedURLToIconURLCacheDirty {
			saveFeedURLToIconURLCache()
		}
	}

	func queueSaveFeedURLToIconURLCacheIfNeeded() {

		assert(Thread.isMainThread)
		FeedIconDownloader.saveQueue.add(self, #selector(saveFeedURLToIconURLCacheIfNeeded))
	}

	func saveFeedURLToIconURLCache() {
		feedURLToIconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		do {
			let data = try encoder.encode(feedURLToIconURLCache)
			try data.write(to: feedURLToIconURLCachePath)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
}
