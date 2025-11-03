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

public final class FeedIconDownloader {

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

		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: imageDownloader)
	}

	func icon(for feed: Feed) -> IconImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}
		
		if let homePageURLString = feed.homePageURL, let homePageURL = URL(string: homePageURLString), (homePageURL.host == "nnw.ranchero.com" || homePageURL.host == "netnewswire.blog") {
			return IconImage.nnwFeedIcon
		}
		if (Self.shouldSkipDownloadingFeedIcon(feed: feed)) {
			return nil
		}

		func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}
			if homePagesWithNoIconURL.contains(homePageURL) {
				return
			}
			icon(forHomePageURL: homePageURL, feed: feed) { image, iconURL in
				if let image, let iconURL {
					self.cache[feed] = IconImage(image)
					self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
					self.postFeedIconDidBecomeAvailableNotification(feed)
				}
			}
		}
		
		func checkFeedIconURL() {
			if let iconURL = feed.iconURL {
				icon(forURL: iconURL, feed: feed) { (image) in
					if let image = image {
						self.cache[feed] = IconImage(image)
						self.cacheIconURLForFeedURL(iconURL: iconURL, feedURL: feed.url)
						self.postFeedIconDidBecomeAvailableNotification(feed)
					} else {
						checkHomePageURL()
					}
				}
			} else {
				checkHomePageURL()
			}
		}

		if let previouslyFoundIconURL = feedURLToIconURLCache[feed.url] {
			icon(forURL: previouslyFoundIconURL, feed: feed) { image in
				if let image {
					self.postFeedIconDidBecomeAvailableNotification(feed)
					self.cache[feed] = IconImage(image)
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

	static func shouldSkipDownloadingFeedIcon(feed: Feed) -> Bool {
		shouldSkipDownloadingFeedIcon(feed.url)
	}

	static func shouldSkipDownloadingFeedIcon(_ urlString: String) -> Bool {
		SpecialCase.urlStringContainSpecialCase(urlString, specialCasesToSkip)
	}

	func icon(forHomePageURL homePageURL: String, feed: Feed, _ resultBlock: @escaping (RSImage?, String?) -> Void) {
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
				resultBlock(image, url)
			}
			return
		}

		homePagesWithNoIconURL.insert(homePageURL)
		resultBlock(nil, nil)
	}

	func icon(forURL url: String, feed: Feed, _ imageResultBlock: @escaping (RSImage?) -> Void) {

		waitingForFeedURLs[url] = feed
		guard let imageData = imageDownloader.image(for: url) else {
			imageResultBlock(nil)
			return
		}
		RSImage.scaledForIcon(imageData, imageResultBlock: imageResultBlock)
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
