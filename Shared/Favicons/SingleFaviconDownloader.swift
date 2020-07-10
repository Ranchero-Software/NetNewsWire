//
//  SingleFaviconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSWeb

// The image may be on disk already. If not, download it.
// Post .DidLoadFavicon notification once it’s in memory.

extension Notification.Name {

	static let DidLoadFavicon = Notification.Name("DidLoadFaviconNotification")
}

final class SingleFaviconDownloader {

	enum DiskStatus {
		case unknown, notOnDisk, onDisk
	}

	let faviconURL: String
	var iconImage: IconImage?
	let homePageURL: String?

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "SingleFaviconDownloader")
	
	private var lastDownloadAttemptDate: Date
	private var diskStatus = DiskStatus.unknown
	private var diskCache: BinaryDiskCache
	private let queue: DispatchQueue

	private var diskKey: String {
		return faviconURL.md5String
	}

	init(faviconURL: String, homePageURL: String?, diskCache: BinaryDiskCache, queue: DispatchQueue) {

		self.faviconURL = faviconURL
		self.homePageURL = homePageURL
		self.diskCache = diskCache
		self.queue = queue
		self.lastDownloadAttemptDate = Date()

		findFavicon()
	}

	func downloadFaviconIfNeeded() -> Bool {

		// If we don’t have an image, and lastDownloadAttemptDate is a while ago, try again.

		if let _ = iconImage {
			return false
		}

		let retryInterval: TimeInterval = 30 * 60 // 30 minutes
		if Date().timeIntervalSince(lastDownloadAttemptDate) < retryInterval {
			return false
		}

		lastDownloadAttemptDate = Date()
		findFavicon()
		
		return true
	}
}

private extension SingleFaviconDownloader {

	func findFavicon() {

		readFromDisk { (image) in

			if let image = image {
				self.diskStatus = .onDisk
				self.iconImage = IconImage(image)
				self.postDidLoadFaviconNotification()
				return
			}

			self.diskStatus = .notOnDisk

			self.downloadFavicon { (image) in

				if let image = image {
					self.iconImage = IconImage(image)
				}

				self.postDidLoadFaviconNotification()
				
			}
		}
	}

	func readFromDisk(_ completion: @escaping (RSImage?) -> Void) {

		guard diskStatus != .notOnDisk else {
			completion(nil)
			return
		}

		queue.async {

			if let data = self.diskCache[self.diskKey], !data.isEmpty {
				RSImage.image(with: data, imageResultBlock: completion)
				return
			}

			DispatchQueue.main.async {
				completion(nil)
			}
		}
	}

	func saveToDisk(_ data: Data) {

		queue.async {

			do {
				try self.diskCache.setData(data, forKey: self.diskKey)
				DispatchQueue.main.async {
					self.diskStatus = .onDisk
				}
			}
			catch {}
		}
	}

	func downloadFavicon(_ completion: @escaping (RSImage?) -> Void) {

		guard let url = URL(string: faviconURL) else {
			completion(nil)
			return
		}

		downloadUsingCache(url) { (data, response, error) in

			if let data = data, !data.isEmpty, let response = response, response.statusIsOK, error == nil {
				self.saveToDisk(data)
				RSImage.image(with: data, imageResultBlock: completion)
				return
			}

			if let error = error {
				os_log(.info, log: self.log, "Error downloading image at %@: %@.", url.absoluteString, error.localizedDescription)
			}

			completion(nil)
		}
	}

	func postDidLoadFaviconNotification() {

		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
	}
	
}
