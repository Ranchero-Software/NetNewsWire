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
import ParserObjC
import Core

public extension Notification.Name {

	static let FeedIconDidBecomeAvailable = Notification.Name("FeedIconDidBecomeAvailableNotification") // UserInfoKey.feed
}

public protocol FeedIconDownloaderDelegate: Sendable {

	@MainActor var appIconImage: IconImage? { get }

	func downloadMetadata(_ url: String) async throws -> RSHTMLMetadata?
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
	private var homePagesWithNoIconURLCachePath: URL
	private var homePagesWithNoIconURLCacheDirty = false {
		didSet {
			queueHomePagesWithNoIconURLCacheIfNeeded()
		}
	}

	private var homePagesWithUglyIcons: Set<String> = {
		return Set(["https://www.macsparky.com/", "https://xkcd.com/"])
	}()
	
	private var urlsInProgress = Set<String>()
	private var cache = [Feed: IconImage]()
	private var waitingForFeedURLs = [String: Feed]()
	
	public var delegate: FeedIconDownloaderDelegate?

	public init() {

		let folder = AppConfig.cacheSubfolder(named: "FeedIcons")

		self.feedURLToIconURLCachePath = folder.appendingPathComponent("FeedURLToIconURLCache.plist")
		self.homePageToIconURLCachePath = folder.appendingPathComponent("HomePageToIconURLCache.plist")
		self.homePagesWithNoIconURLCachePath = folder.appendingPathComponent("HomePagesWithNoIconURLCache.plist")
		loadFeedURLToIconURLCache()
		loadHomePageToIconURLCache()
		loadHomePagesWithNoIconURLCache()
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
			return delegate?.appIconImage
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
	
	@objc func saveHomePagesWithNoIconURLCacheIfNeeded() {
		if homePagesWithNoIconURLCacheDirty {
			saveHomePagesWithNoIconURLCache()
		}
	}
	
}

private extension FeedIconDownloader {

	func icon(forHomePageURL homePageURL: String, feed: Feed) async -> RSImage? {

		if homePagesWithNoIconURLCache.contains(homePageURL) || homePagesWithUglyIcons.contains(homePageURL) {
			return nil
		}

		if let iconURL = cachedIconURL(for: homePageURL) {
			return await icon(forURL: iconURL, feed: feed)
		}

		findIconURLForHomePageURL(homePageURL, feed: feed, downloadMetadata: delegate!.downloadMetadata(_:))

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
		homePagesWithNoIconURLCacheDirty = true
		homePageToIconURLCache[homePageURL] = iconURL
		homePageToIconURLCacheDirty = true
	}

	func findIconURLForHomePageURL(_ homePageURL: String, feed: Feed, downloadMetadata: @escaping (String) async throws -> RSHTMLMetadata?) {

		guard !urlsInProgress.contains(homePageURL) else {
			return
		}
		urlsInProgress.insert(homePageURL)

		Task { @MainActor in

			let metadata = try? await downloadMetadata(homePageURL)

			self.urlsInProgress.remove(homePageURL)
			guard let metadata else {
				return
			}
			self.pullIconURL(from: metadata, homePageURL: homePageURL, feed: feed)
		}
	}

	func pullIconURL(from metadata: RSHTMLMetadata, homePageURL: String, feed: Feed) {

		if let url = metadata.bestWebsiteIconURL() {
			cacheIconURL(for: homePageURL, url)
			Task { @MainActor in
				await icon(forURL: url, feed: feed)
			}
			return
		}

		homePagesWithNoIconURLCache.insert(homePageURL)
		homePagesWithNoIconURLCacheDirty = true
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

	func loadHomePagesWithNoIconURLCache() {
		guard let data = try? Data(contentsOf: homePagesWithNoIconURLCachePath) else {
			return
		}
		let decoder = PropertyListDecoder()
		let decoded = (try? decoder.decode([String].self, from: data)) ?? [String]()
		homePagesWithNoIconURLCache = Set(decoded)
	}

	@MainActor func queueSaveFeedURLToIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveFeedURLToIconURLCacheIfNeeded))
	}

	@MainActor func queueSaveHomePageToIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveHomePageToIconURLCacheIfNeeded))
	}

	@MainActor func queueHomePagesWithNoIconURLCacheIfNeeded() {
		FeedIconDownloader.saveQueue.add(self, #selector(saveHomePagesWithNoIconURLCacheIfNeeded))
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
	
	func saveHomePagesWithNoIconURLCache() {
		homePagesWithNoIconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		do {
			let data = try encoder.encode(Array(homePagesWithNoIconURLCache))
			try data.write(to: homePagesWithNoIconURLCachePath)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
}
