//
//  FeedIconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account
import Web
import Parser
import Core

public extension Notification.Name {

	static let FeedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailableNotification") // UserInfoKey.feed
}

@MainActor public final class FeedIconDownloader {

	public static let shared = FeedIconDownloader()

	public static let feedKey = "url"
	
	private static let saveQueue = CoalescingQueue(name: "Cache Save Queue", interval: 1.0)

	private let imageDownloader = ImageDownloader.shared

	private var feedURLToIconURLCache = [String: String]()
	private var feedURLToIconURLCachePath: URL
	private var feedURLToIconURLCacheDirty = false {
		didSet {
			queueSaveFeedURLToIconURLCacheIfNeeded()
		}
	}
	
	private var homePageToIconURLCache = [String: String]()
	private var homePageToIconURLCachePath: URL
	private var homePageToIconURLCacheDirty = false {
		didSet {
			queueSaveHomePageToIconURLCacheIfNeeded()
		}
	}
	
	private var homePagesWithNoIconURLCache = Set<String>()
	private var homePagesWithUglyIcons: Set<String> = {
		return Set(["https://www.macsparky.com/", "https://xkcd.com/"])
	}()
	
	private var cache = [Feed: IconImage]()
	private var waitingForFeedURLs = [String: Feed]()

	public init() {

		let folder = AppConfig.cacheSubfolder(named: "FeedIcons")

		self.feedURLToIconURLCachePath = folder.appendingPathComponent("FeedURLToIconURLCache.plist")
		self.homePageToIconURLCachePath = folder.appendingPathComponent("HomePageToIconURLCache.plist")
		loadFeedURLToIconURLCache()
		loadHomePageToIconURLCache()
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: imageDownloader)
	}

	func resetCache() {
		cache = [Feed: IconImage]()
	}

	public func icon(for feed: Feed) -> IconImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}
		
		if let hpURLString = feed.homePageURL, let hpURL = URL(string: hpURLString), (hpURL.host == "nnw.ranchero.com" || hpURL.host == "netnewswire.blog") {
			return IconImage.appIcon
		}

		@MainActor func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}

			Task { @MainActor in
				if let image = await icon(forHomePageURL: homePageURL, feed: feed) {
					postFeedIconDidBecomeAvailableNotification(feed)
					cache[feed] = IconImage(image)
				}
			}
		}
		
		func checkFeedIconURL() {
			guard let iconURL = feed.iconURL else {
				checkHomePageURL()
				return
			}

			Task { @MainActor in
				if let image = await icon(forURL: iconURL, feed: feed) {
					postFeedIconDidBecomeAvailableNotification(feed)
					cache[feed] = IconImage(image)
				} else {
					checkHomePageURL()
				}
			}
		}

		if let feedProviderURL = feedURLToIconURLCache[feed.url] {

			Task { @MainActor in
				if let image = await icon(forURL: feedProviderURL, feed: feed) {
					postFeedIconDidBecomeAvailableNotification(feed)
					cache[feed] = IconImage(image)
				}
			}

			return nil
		}
		
		checkFeedIconURL()

		return nil
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		guard let url = note.userInfo?[ImageDownloader.imageURLKey] as? String, let feed = waitingForFeedURLs[url]  else {
			return
		}
		waitingForFeedURLs[url] = nil
		_ = icon(for: feed)
	}
	
	@objc func saveFeedURLToIconURLCacheIfNeeded() {
		if feedURLToIconURLCacheDirty {
			saveFeedURLToIconURLCache()
		}
	}
	
	@objc func saveHomePageToIconURLCacheIfNeeded() {
		if homePageToIconURLCacheDirty {
			saveHomePageToIconURLCache()
		}
	}
}

private extension FeedIconDownloader {

	func icon(forHomePageURL homePageURL: String, feed: Feed) async -> RSImage? {

		if let iconURL = cachedIconURL(for: homePageURL) {
			return await icon(forURL: iconURL, feed: feed)
		}

		if homePagesWithNoIconURLCache.contains(homePageURL) || homePagesWithUglyIcons.contains(homePageURL) {
			return nil
		}

		guard let metadata = HTMLMetadataDownloader.cachedMetadata(for: homePageURL) else {
			return nil
		}

		if let url = metadata.bestWebsiteIconURL() {
			cacheIconURL(for: homePageURL, url)
			return await icon(forURL: url, feed: feed)
		}

		homePagesWithNoIconURLCache.insert(homePageURL)

		return nil
	}

	func icon(forURL url: String, feed: Feed) async -> RSImage? {

		waitingForFeedURLs[url] = feed

		guard let imageData = imageDownloader.image(for: url) else {
			return nil
		}
		return await RSImage.scaledForIcon(imageData)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: Feed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [Self.feedKey: feed]
			NotificationCenter.default.post(name: .FeedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func cachedIconURL(for homePageURL: String) -> String? {

		return homePageToIconURLCache[homePageURL]
	}

	func cacheIconURL(for homePageURL: String, _ iconURL: String) {
		homePagesWithNoIconURLCache.remove(homePageURL)
		homePageToIconURLCache[homePageURL] = iconURL
		homePageToIconURLCacheDirty = true
	}

	func loadFeedURLToIconURLCache() {
		guard let data = try? Data(contentsOf: feedURLToIconURLCachePath) else {
			return
		}
		let decoder = PropertyListDecoder()
		feedURLToIconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	func loadHomePageToIconURLCache() {
		guard let data = try? Data(contentsOf: homePageToIconURLCachePath) else {
			return
		}
		let decoder = PropertyListDecoder()
		homePageToIconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	@MainActor func queueSaveFeedURLToIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveFeedURLToIconURLCacheIfNeeded))
	}

	@MainActor func queueSaveHomePageToIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveHomePageToIconURLCacheIfNeeded))
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
	
	func saveHomePageToIconURLCache() {
		homePageToIconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		do {
			let data = try encoder.encode(homePageToIconURLCache)
			try data.write(to: homePageToIconURLCachePath)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
}
