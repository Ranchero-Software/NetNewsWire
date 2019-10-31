//
//  FaviconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account
import RSCore

extension Notification.Name {

	static let FaviconDidBecomeAvailable = Notification.Name("FaviconDidBecomeAvailableNotification") // userInfo key: FaviconDownloader.UserInfoKey.faviconURL
}

final class FaviconDownloader {

	private static let saveQueue = CoalescingQueue(name: "Cache Save Queue", interval: 1.0)

	private let folder: String
	private let diskCache: BinaryDiskCache
	private var singleFaviconDownloaderCache = [String: SingleFaviconDownloader]() // faviconURL: SingleFaviconDownloader
	
	private var homePageToFaviconURLCache = [String: String]() //homePageURL: faviconURL
	private var homePageToFaviconURLCachePath: String
	private var homePageToFaviconURLCacheDirty = false {
		didSet {
			queueSaveHomePageToFaviconURLCacheIfNeeded()
		}
	}

	private var homePageURLsWithNoFaviconURLCache = Set<String>()
	private var homePageURLsWithNoFaviconURLCachePath: String
	private var homePageURLsWithNoFaviconURLCacheDirty = false {
		didSet {
			queueSaveHomePageURLsWithNoFaviconURLCacheIfNeeded()
		}
	}

	private let queue: DispatchQueue
	private var cache = [Feed: RSImage]() // faviconURL: RSImage

	struct UserInfoKey {
		static let faviconURL = "faviconURL"
	}

	init(folder: String) {

		self.folder = folder
		self.diskCache = BinaryDiskCache(folder: folder)
		self.queue = DispatchQueue(label: "FaviconDownloader serial queue - \(folder)")

		self.homePageToFaviconURLCachePath = (folder as NSString).appendingPathComponent("HomePageToFaviconURLCache.plist")
		self.homePageURLsWithNoFaviconURLCachePath = (folder as NSString).appendingPathComponent("HomePageURLsWithNoFaviconURLCache.plist")
		loadHomePageToFaviconURLCache()
		loadHomePageURLsWithNoFaviconURLCache()

		NotificationCenter.default.addObserver(self, selector: #selector(didLoadFavicon(_:)), name: .DidLoadFavicon, object: nil)
	}

	// MARK: - API

	func resetCache() {
		cache = [Feed: RSImage]()
	}
	
	func favicon(for feed: Feed) -> RSImage? {

		assert(Thread.isMainThread)

		if let faviconURL = feed.faviconURL {
			return favicon(with: faviconURL)
		}

		var homePageURL = feed.homePageURL
		if homePageURL == nil {
			// Base homePageURL off feedURL if needed. Won’t always be accurate, but is good enough.
			if let feedURL = URL(string: feed.url), let scheme = feedURL.scheme, let host = feedURL.host {
				homePageURL = scheme + "://" + host + "/"
			}
		}
		if let homePageURL = homePageURL {
			return favicon(withHomePageURL: homePageURL)
		}

		return nil
	}
	
	func faviconAsAvatar(for feed: Feed) -> RSImage? {
		
		if let image = cache[feed] {
			return image
		}
		
		if let image = favicon(for: feed), let imageData = image.dataRepresentation() {
			if let scaledImage = RSImage.scaledForAvatar(imageData) {
				cache[feed] = scaledImage
				return scaledImage
			}
		}
		
		return nil
	}

	func favicon(with faviconURL: String) -> RSImage? {

		let downloader = faviconDownloader(withURL: faviconURL)
		return downloader.image
	}

	func favicon(withHomePageURL homePageURL: String) -> RSImage? {

		let url = homePageURL.rs_normalizedURL()
		if homePageURLsWithNoFaviconURLCache.contains(url) {
			return nil
		}
		
		if let faviconURL = homePageToFaviconURLCache[url] {
			return favicon(with: faviconURL)
		}

		findFaviconURL(with: url) { (faviconURL) in
			if let faviconURL = faviconURL {
				self.homePageToFaviconURLCache[url] = faviconURL
				self.homePageToFaviconURLCacheDirty = true
				let _ = self.favicon(with: faviconURL)
			}
			else {
				self.homePageURLsWithNoFaviconURLCache.insert(url)
				self.homePageURLsWithNoFaviconURLCacheDirty = true
			}
		}

		return nil
	}

	// MARK: - Notifications

	@objc func didLoadFavicon(_ note: Notification) {

		guard let singleFaviconDownloader = note.object as? SingleFaviconDownloader else {
			return
		}
		guard let _ = singleFaviconDownloader.image else {
			return
		}

		postFaviconDidBecomeAvailableNotification(singleFaviconDownloader.faviconURL)
	}
	
	@objc func saveHomePageToFaviconURLCacheIfNeeded() {
		if homePageToFaviconURLCacheDirty {
			saveHomePageToFaviconURLCache()
		}
	}
	
	@objc func saveHomePageURLsWithNoFaviconURLCacheIfNeeded() {
		if homePageURLsWithNoFaviconURLCacheDirty {
			saveHomePageURLsWithNoFaviconURLCache()
		}
	}
}

private extension FaviconDownloader {

	static let localeForLowercasing = Locale(identifier: "en_US")

	func findFaviconURL(with homePageURL: String, _ completion: @escaping (String?) -> Void) {

		guard let url = URL(string: homePageURL) else {
			completion(nil)
			return
		}

		FaviconURLFinder.findFaviconURL(homePageURL) { (faviconURL) in

			if let faviconURL = faviconURL {
				completion(faviconURL)
				return
			}

			guard let scheme = url.scheme, let host = url.host else {
				completion(nil)
				return
			}

			let defaultFaviconURL = "\(scheme)://\(host)/favicon.ico".lowercased(with: FaviconDownloader.localeForLowercasing)
			completion(defaultFaviconURL)
		}
	}

	func faviconDownloader(withURL faviconURL: String) -> SingleFaviconDownloader {

		if let downloader = singleFaviconDownloaderCache[faviconURL] {
			downloader.downloadFaviconIfNeeded()
			return downloader
		}

		let downloader = SingleFaviconDownloader(faviconURL: faviconURL, diskCache: diskCache, queue: queue)
		singleFaviconDownloaderCache[faviconURL] = downloader
		return downloader
	}

	func postFaviconDidBecomeAvailableNotification(_ faviconURL: String) {

		DispatchQueue.main.async {
			let userInfo: [AnyHashable: Any] = [UserInfoKey.faviconURL: faviconURL]
			NotificationCenter.default.post(name: .FaviconDidBecomeAvailable, object: self, userInfo: userInfo)
		}
	}

	func loadHomePageToFaviconURLCache() {
		let url = URL(fileURLWithPath: homePageToFaviconURLCachePath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		homePageToFaviconURLCache = (try? decoder.decode([String: String].self, from: data)) ?? [String: String]()
	}

	func loadHomePageURLsWithNoFaviconURLCache() {
		let url = URL(fileURLWithPath: homePageURLsWithNoFaviconURLCachePath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		let decoded = (try? decoder.decode([String].self, from: data)) ?? [String]()
		homePageURLsWithNoFaviconURLCache = Set(decoded)
	}

	func queueSaveHomePageToFaviconURLCacheIfNeeded() {
		FaviconDownloader.saveQueue.add(self, #selector(saveHomePageToFaviconURLCacheIfNeeded))
	}

	func queueSaveHomePageURLsWithNoFaviconURLCacheIfNeeded() {
		FaviconDownloader.saveQueue.add(self, #selector(saveHomePageURLsWithNoFaviconURLCacheIfNeeded))
	}

	func saveHomePageToFaviconURLCache() {
		homePageToFaviconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: homePageToFaviconURLCachePath)
		do {
			let data = try encoder.encode(homePageToFaviconURLCache)
			try data.write(to: url)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}
	
	func saveHomePageURLsWithNoFaviconURLCache() {
		homePageURLsWithNoFaviconURLCacheDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: homePageURLsWithNoFaviconURLCachePath)
		do {
			let data = try encoder.encode(Array(homePageURLsWithNoFaviconURLCache))
			try data.write(to: url)
		} catch {
			assertionFailure(error.localizedDescription)
		}
	}

}
