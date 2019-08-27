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

	static let FeedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailableNotification") // UserInfoKey.feed
}

public final class FeedIconDownloader {

	private static let saveQueue = CoalescingQueue(name: "Cache Save Queue", interval: 1.0)

	private let imageDownloader: ImageDownloader

	private var homePageToIconURLCache = [String: String]()
	private var homePageToIconURLCachePath: String
	private var homePageToIconURLCacheDirty = false {
		didSet {
			queueSaveHomePageToIconURLCacheIfNeeded()
		}
	}
	
	private var homePagesWithNoIconURL = Set<String>()
	private var urlsInProgress = Set<String>()
	private var cache = [Feed: RSImage]()
	private var waitingForFeedURLs = [String: Feed]()

	init(imageDownloader: ImageDownloader, folder: String) {
		self.imageDownloader = imageDownloader
		self.homePageToIconURLCachePath = (folder as NSString).appendingPathComponent("HomePageToIconURLCache.plist")
		loadHomePageToIconURLCache()
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: imageDownloader)
	}

	func resetCache() {
		cache = [Feed: RSImage]()
	}

	func icon(for feed: Feed) -> RSImage? {

		if let cachedImage = cache[feed] {
			return cachedImage
		}
		
		func checkHomePageURL() {
			guard let homePageURL = feed.homePageURL else {
				return
			}
			icon(forHomePageURL: homePageURL, feed: feed) { (image) in
				if let image = image {
					self.postFeedIconDidBecomeAvailableNotification(feed)
					self.cache[feed] = image
				}
			}
		}

		if let iconURL = feed.iconURL {
			icon(forURL: iconURL, feed: feed) { (image) in
				if let image = image {
					self.postFeedIconDidBecomeAvailableNotification(feed)
					self.cache[feed] = image
				}
				else {
					checkHomePageURL()
				}
			}
		}
		else {
			checkHomePageURL()
		}


		return nil
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		guard let url = note.userInfo?[UserInfoKey.url] as? String, let feed = waitingForFeedURLs[url]  else {
			return
		}
		waitingForFeedURLs[url] = nil
		_ = icon(for: feed)
	}
	
	@objc func saveHomePageToIconURLCacheIfNeeded() {
		if homePageToIconURLCacheDirty {
			saveHomePageToIconURLCache()
		}
	}
	
}

private extension FeedIconDownloader {

	func icon(forHomePageURL homePageURL: String, feed: Feed, _ imageResultBlock: @escaping (RSImage?) -> Void) {

		if homePagesWithNoIconURL.contains(homePageURL) {
			imageResultBlock(nil)
			return
		}

		if let iconURL = cachedIconURL(for: homePageURL) {
			icon(forURL: iconURL, feed: feed, imageResultBlock)
			return
		}

		findIconURLForHomePageURL(homePageURL, feed: feed)
	}

	func icon(forURL url: String, feed: Feed, _ imageResultBlock: @escaping (RSImage?) -> Void) {
		waitingForFeedURLs[url] = feed
		guard let imageData = imageDownloader.image(for: url) else {
			imageResultBlock(nil)
			return
		}
		RSImage.scaledForAvatar(imageData, imageResultBlock: imageResultBlock)
	}

	func postFeedIconDidBecomeAvailableNotification(_ feed: Feed) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.feed: feed]
			NotificationCenter.default.post(name: .FeedIconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func cachedIconURL(for homePageURL: String) -> String? {

		return homePageToIconURLCache[homePageURL]
	}

	func cacheIconURL(for homePageURL: String, _ iconURL: String) {
		homePagesWithNoIconURL.remove(homePageURL)
		homePageToIconURLCache[homePageURL] = iconURL
		homePageToIconURLCacheDirty = true
	}

	func findIconURLForHomePageURL(_ homePageURL: String, feed: Feed) {

		guard !urlsInProgress.contains(homePageURL) else {
			return
		}
		urlsInProgress.insert(homePageURL)

		HTMLMetadataDownloader.downloadMetadata(for: homePageURL) { (metadata) in

			self.urlsInProgress.remove(homePageURL)
			guard let metadata = metadata else {
				return
			}
			self.pullIconURL(from: metadata, homePageURL: homePageURL, feed: feed)
		}
	}

	func pullIconURL(from metadata: RSHTMLMetadata, homePageURL: String, feed: Feed) {

		if let url = metadata.bestWebsiteIconURL() {
			cacheIconURL(for: homePageURL, url)
			icon(forURL: url, feed: feed) { (image) in
			}
			return
		}

		homePagesWithNoIconURL.insert(homePageURL)
	}
	
	func loadHomePageToIconURLCache() {
		let url = URL(fileURLWithPath: homePageToIconURLCachePath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		homePageToIconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	func queueSaveHomePageToIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveHomePageToIconURLCacheIfNeeded))
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
