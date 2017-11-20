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

		if let faviconURL = faviconURL(for: feed) {

			if let cachedFavicon = cache[faviconURL] {
				return cachedFavicon
			}
			if shouldDownloadFaviconURL(faviconURL) {
				downloadFavicon(faviconURL)
				return nil
			}
		}

		return nil
	}
}

private extension FaviconDownloader {

	func shouldDownloadFaviconURL(_ faviconURL: String) -> Bool {

		return !urlsBeingDownloaded.contains(faviconURL)
	}

	func downloadFavicon(_ faviconURL: String) {

		guard let url = URL(string: faviconURL) else {
			return
		}

		urlsBeingDownloaded.insert(faviconURL)

		download(url) { (data, response, error) in

			self.urlsBeingDownloaded.remove(faviconURL)
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
