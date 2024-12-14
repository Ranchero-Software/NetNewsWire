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
import RSCore
import RSWeb
import RSParser

extension Notification.Name {

	static let feedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailable") // UserInfoKey.feed
}

public final class FeedIconDownloader {

	private static let saveQueue = CoalescingQueue(name: "Cache Save Queue", interval: 1.0)

	private let imageDownloader: ImageDownloader

	private var feedURLToIconURLCache = [String: String]()
	private var feedURLToIconURLCachePath: String
	private var feedURLToIconURLCacheDirty = false {
		didSet {
			queueSaveFeedURLToIconURLCacheIfNeeded()
		}
	}
	
	private var homePageToIconURLCache = [String: String]()
	private var homePageToIconURLCachePath: String
	private var homePageToIconURLCacheDirty = false {
		didSet {
			queueSaveHomePageToIconURLCacheIfNeeded()
		}
	}
	
	private var homePagesWithNoIconURLCache = Set<String>()
	private var homePagesWithUglyIcons: Set<String> = {
		return Set(["https://www.macsparky.com/", "https://xkcd.com/"])
	}()
	private var feedsWithNoIconURL = [String: WebFeed]()

	private var urlsInProgress = Set<String>()
	private var cache = [WebFeed: IconImage]()
	private var waitingForFeedURLs = [String: WebFeed]()
	
	init(imageDownloader: ImageDownloader, folder: String) {
		self.imageDownloader = imageDownloader
		self.feedURLToIconURLCachePath = (folder as NSString).appendingPathComponent("FeedURLToIconURLCache.plist")
		self.homePageToIconURLCachePath = (folder as NSString).appendingPathComponent("HomePageToIconURLCache.plist")
		loadFeedURLToIconURLCache()
		loadHomePageToIconURLCache()
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: imageDownloader)
	}

	func resetCache() {
		cache = [WebFeed: IconImage]()
	}

	func icon(for feed: WebFeed) -> IconImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}
		
		if let hpURLString = feed.homePageURL, let hpURL = URL(string: hpURLString), (hpURL.host == "nnw.ranchero.com" || hpURL.host == "netnewswire.blog") {
			return IconImage.appIcon
		}

		if feedsWithNoIconURL[feed.url] != nil {
			return nil
		}

		func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}
			if homePagesWithNoIconURLCache.contains(homePageURL) {
				return
			}
			icon(forHomePageURL: homePageURL, feed: feed) { (image) in
				if let image {
					self.postFeedIconDidBecomeAvailableNotification(feed)
					self.cache[feed] = IconImage(image)
				}
				else {
					self.homePagesWithNoIconURLCache.insert(homePageURL)
					self.feedsWithNoIconURL[feed.url] = feed
				}
			}
		}
		
		func checkFeedIconURL() {
			if let iconURL = feed.iconURL {
				icon(forURL: iconURL, feed: feed) { (image) in
					if let image = image {
						self.postFeedIconDidBecomeAvailableNotification(feed)
						self.cache[feed] = IconImage(image)
					} else {
						checkHomePageURL()
					}
				}
			} else {
				checkHomePageURL()
			}
		}
		
		if let feedProviderURL = feedURLToIconURLCache[feed.url] {
			self.icon(forURL: feedProviderURL, feed: feed) { (image) in
				if let image = image {
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
		guard let url = note.userInfo?[UserInfoKey.url] as? String, let feed = waitingForFeedURLs[url]  else {
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

	func icon(forHomePageURL homePageURL: String, feed: WebFeed, _ imageResultBlock: @escaping (RSImage?) -> Void) {

		if homePagesWithNoIconURLCache.contains(homePageURL) || homePagesWithUglyIcons.contains(homePageURL) {
			imageResultBlock(nil)
			return
		}

		if let iconURL = cachedIconURL(for: homePageURL) {
			icon(forURL: iconURL, feed: feed, imageResultBlock)
			return
		}

		guard let metadata = HTMLMetadataDownloader.shared.cachedMetadata(for: homePageURL) else {
			imageResultBlock(nil)
			return
		}

		if let url = metadata.bestWebsiteIconURL() {
			cacheIconURL(for: homePageURL, url)
			icon(forURL: url, feed: feed, imageResultBlock)
			return
		}

		homePagesWithNoIconURLCache.insert(homePageURL)
	}

	func icon(forURL url: String, feed: WebFeed, _ imageResultBlock: @escaping (RSImage?) -> Void) {
		waitingForFeedURLs[url] = feed
		guard let imageData = imageDownloader.image(for: url) else {
			imageResultBlock(nil)
			return
		}
		RSImage.scaledForIcon(imageData, imageResultBlock: imageResultBlock)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: WebFeed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.webFeed: feed]
			NotificationCenter.default.post(name: .feedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func cachedIconURL(for homePageURL: String) -> String? {

		return homePageToIconURLCache[homePageURL]
	}

	func cacheIconURL(for homePageURL: String, _ iconURL: String) {

		homePagesWithNoIconURLCache.remove(homePageURL)

		if homePageToIconURLCache[homePageURL] != iconURL {
			homePageToIconURLCache[homePageURL] = iconURL
			homePageToIconURLCacheDirty = true
		}
	}

	func loadFeedURLToIconURLCache() {
		let url = URL(fileURLWithPath: feedURLToIconURLCachePath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		feedURLToIconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	func loadHomePageToIconURLCache() {
		let url = URL(fileURLWithPath: homePageToIconURLCachePath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		homePageToIconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	func queueSaveFeedURLToIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveFeedURLToIconURLCacheIfNeeded))
	}

	func queueSaveHomePageToIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveHomePageToIconURLCacheIfNeeded))
	}

	func saveFeedURLToIconURLCache() {
		feedURLToIconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: feedURLToIconURLCachePath)
		do {
			let data = try encoder.encode(feedURLToIconURLCache)
			try data.write(to: url)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
	
	func saveHomePageToIconURLCache() {
		homePageToIconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: homePageToIconURLCachePath)
		do {
			let data = try encoder.encode(homePageToIconURLCache)
			try data.write(to: url)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
}
