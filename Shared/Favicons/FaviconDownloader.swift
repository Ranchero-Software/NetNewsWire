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
	private var remainingFaviconURLs = [String: ArraySlice<String>]() // homePageURL: array of faviconURLs that haven't been checked yet

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

		var homePageURL = feed.homePageURL
		if let faviconURL = feed.faviconURL {
			return favicon(with: faviconURL, homePageURL: homePageURL)
		}

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

	func favicon(with faviconURL: String, homePageURL: String?) -> RSImage? {

		let downloader = faviconDownloader(withURL: faviconURL, homePageURL: homePageURL)
		return downloader.image
	}

	func favicon(withHomePageURL homePageURL: String) -> RSImage? {

		let url = homePageURL.rs_normalizedURL()
		if homePageURLsWithNoFaviconURL.contains(url) {
			return nil
		}

		if let faviconURL = homePageToFaviconURLCache[url] {
			return favicon(with: faviconURL, homePageURL: url)
		}

		findFaviconURLs(with: url) { (faviconURLs) in
			var hasIcons = false

			if let faviconURLs = faviconURLs {
				if let firstIconURL = faviconURLs.first {
					hasIcons = true
					let _ = self.favicon(with: firstIconURL, homePageURL: url)
					self.remainingFaviconURLs[url] = faviconURLs.dropFirst()
				}
			}

			if (!hasIcons) {
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
		guard let homePageURL = singleFaviconDownloader.homePageURL else {
			return
		}
		guard let _ = singleFaviconDownloader.image else {
			if let faviconURLs = remainingFaviconURLs[homePageURL] {
				if let nextIconURL = faviconURLs.first {
					let _ = favicon(with: nextIconURL, homePageURL: singleFaviconDownloader.homePageURL)
					remainingFaviconURLs[homePageURL] = faviconURLs.dropFirst();
				} else {
					remainingFaviconURLs[homePageURL] = nil
				}
			}
			return
		}

		remainingFaviconURLs[homePageURL] = nil

		if let url = singleFaviconDownloader.homePageURL {
			if self.homePageToFaviconURLCache[url] == nil {
				self.homePageToFaviconURLCache[url] = singleFaviconDownloader.faviconURL
			}
		}

		postFaviconDidBecomeAvailableNotification(singleFaviconDownloader.faviconURL)
	}
}

private extension FaviconDownloader {

	static let localeForLowercasing = Locale(identifier: "en_US")

	func findFaviconURLs(with homePageURL: String, _ completion: @escaping ([String]?) -> Void) {

		guard let url = URL(string: homePageURL) else {
			completion(nil)
			return
		}

		FaviconURLFinder.findFaviconURLs(homePageURL) { (faviconURLs) in
			var defaultFaviconURL: String? = nil

			if let scheme = url.scheme, let host = url.host {
				defaultFaviconURL = "\(scheme)://\(host)/favicon.ico".lowercased(with: FaviconDownloader.localeForLowercasing)
			}

			if var faviconURLs = faviconURLs {
				if let defaultFaviconURL = defaultFaviconURL {
					faviconURLs.append(defaultFaviconURL)
				}
				completion(faviconURLs)
				return
			}

			completion(defaultFaviconURL != nil ? [defaultFaviconURL!] : nil)
		}
	}

	func faviconDownloader(withURL faviconURL: String, homePageURL: String?) -> SingleFaviconDownloader {

		if let downloader = singleFaviconDownloaderCache[faviconURL] {
			downloader.downloadFaviconIfNeeded()
			return downloader
		}

		let downloader = SingleFaviconDownloader(faviconURL: faviconURL, homePageURL: homePageURL, diskCache: diskCache, queue: queue)
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
