//
//  FaviconDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Data
import RSCore
import RSWeb

extension Notification.Name {

	static let FaviconDidBecomeAvailable = Notification.Name("FaviconDidBecomeAvailableNotification") // userInfo keys: homePageURL, faviconURL, image
}

final class FaviconDownloader {

	private var cache = ThreadSafeCache<NSImage>() // faviconURL: NSImage
	private var faviconURLCache = ThreadSafeCache<String>() // homePageURL: faviconURL
	private let folder: String
	private var urlsBeingDownloaded = Set<String>()
	private var badURLs = Set<String>() // URLs that didn’t work for some reason; don’t try again
	private let binaryCache: RSBinaryCache
	private var badImages = Set<String>() // keys for images on disk that NSImage can’t handle
	private let queue: DispatchQueue

	public struct UserInfoKey {
		static let homePageURL = "homePageURL"
		static let faviconURL = "faviconURL"
		static let image = "image" // NSImage
	}

	init(folder: String) {

		self.folder = folder
		self.binaryCache = RSBinaryCache(folder: folder)
		self.queue = DispatchQueue(label: "FaviconCache serial queue - \(folder)")
	}

	// MARK: - API

	func favicon(for feed: Feed) -> NSImage? {

		assert(Thread.isMainThread)

		guard let homePageURL = feed.homePageURL else {
			return nil
		}

		if let faviconURL = faviconURL(for: feed) {

			if let cachedFavicon = cache[faviconURL] {
				return cachedFavicon
			}

			// TODO: read from disk and return if present.

			if shouldDownloadFaviconURL(faviconURL) {
				downloadFavicon(faviconURL, homePageURL)
				return nil
			}

			return nil
		}

		// Try to find the faviconURL. It might be in the web page.
		FaviconURLFinder.findFaviconURL(homePageURL) { (faviconURL) in

			if let faviconURL = faviconURL {
				print(faviconURL) // cache it; then download favicon
			}
			else {
				// Try appending /favicon.ico
				// It often works.
			}
		}

		return nil
	}
}

private extension FaviconDownloader {

	func shouldDownloadFaviconURL(_ faviconURL: String) -> Bool {

		return !urlsBeingDownloaded.contains(faviconURL) && !badURLs.contains(faviconURL)
	}

	func downloadFavicon(_ faviconURL: String, _ homePageURL: String) {

		guard let url = URL(string: faviconURL) else {
			return
		}

		urlsBeingDownloaded.insert(faviconURL)

		downloadUsingCache(url) { (data, response, error) in

			self.urlsBeingDownloaded.remove(faviconURL)
			if response == nil || !response!.statusIsOK {
				self.badURLs.insert(faviconURL)
			}

			if let data = data {
				self.queue.async {
					let _ = NSImage(data: data)
				}
			}
		}
	}

	func faviconURL(for feed: Feed) -> String? {

		if let faviconURL = feed.faviconURL {
			return faviconURL
		}

		if let homePageURL = feed.homePageURL {
			return faviconURLCache[homePageURL]
		}
		return nil
	}

	func readFaviconFromDisk(_ faviconURL: String, _ callback: @escaping (NSImage?) -> Void) {

		queue.async {
			let image = self.tryToInstantiateNSImageFromDisk(faviconURL)
			DispatchQueue.main.async {
				callback(image)
			}
		}
	}

	func tryToInstantiateNSImageFromDisk(_ faviconURL: String) -> NSImage? {

		// Call on serial queue.

		if badImages.contains(faviconURL) {
			return nil
		}

		let key = keyFor(faviconURL)
		var data: Data?

		do {
			data = try binaryCache.binaryData(forKey: key)
		}
		catch {
			return nil
		}

		if data == nil {
			return nil
		}

		guard let image = NSImage(data: data!) else {
			badImages.insert(faviconURL)
			return nil
		}

		return image
	}

	func keyFor(_ faviconURL: String) -> String {

		return (faviconURL as NSString).rs_md5Hash()
	}
}
