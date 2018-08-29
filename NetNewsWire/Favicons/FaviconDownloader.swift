//
//  FaviconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
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

	func favicon(for feed: Feed) -> NSImage? {

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

	func favicon(with faviconURL: String) -> NSImage? {

		let downloader = faviconDownloader(withURL: faviconURL)
		return downloader.image
	}

	func favicon(withHomePageURL homePageURL: String) -> NSImage? {

		let url = normalizedHomePageURL(homePageURL)
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

	func normalizedHomePageURL(_ url: String) -> String {

		// Many times the homePageURL is missing a trailing /.
		// We add one when needed.

		guard !url.hasSuffix("/") else {
			return url
		}
		let lowercasedURL = url.lowercased(with: FaviconDownloader.localeForLowercasing)
		guard lowercasedURL.hasPrefix("http://") || lowercasedURL.hasPrefix("https://") else {
			return url
		}
		guard url.components(separatedBy: "/").count < 4 else {
			return url
		}
		return url + "/"
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
