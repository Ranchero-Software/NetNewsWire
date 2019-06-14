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

	private let folder: String
	private let diskCache: BinaryDiskCache
	private var singleFaviconDownloaderCache = [String: SingleFaviconDownloader]() // faviconURL: SingleFaviconDownloader
	private var homePageToFaviconURLCache = [String: String]() //homePageURL: faviconURL
	private var homePageURLsWithNoFaviconURL = Set<String>()
	private let queue: DispatchQueue
	private var cache = [Feed: RSImage]() // faviconURL: RSImage

	struct UserInfoKey {
		static let faviconURL = "faviconURL"
	}

	init(folder: String) {

		self.folder = folder
		self.diskCache = BinaryDiskCache(folder: folder)
		self.queue = DispatchQueue(label: "FaviconDownloader serial queue - \(folder)")

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
		if homePageURLsWithNoFaviconURL.contains(url) {
			return nil
		}
		
		if let faviconURL = homePageToFaviconURLCache[url] {
			return favicon(with: faviconURL)
		}

		findFaviconURL(with: url) { (faviconURL) in
			if let faviconURL = faviconURL {
				self.homePageToFaviconURLCache[url] = faviconURL
				let _ = self.favicon(with: faviconURL)
			}
			else {
				self.homePageURLsWithNoFaviconURL.insert(url)
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
}
