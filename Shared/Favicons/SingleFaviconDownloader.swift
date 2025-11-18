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

@MainActor final class SingleFaviconDownloader {
	private enum DiskStatus {
		case unknown, notOnDisk, onDisk
	}

	let faviconURL: String
	let homePageURL: String?

	var iconImage: IconImage?

	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SingleFaviconDownloader")

	private let diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private let diskKey: String

	private var lastDownloadAttemptDate: Date
	private var diskStatus = DiskStatus.unknown

	init(faviconURL: String, homePageURL: String?, diskCache: BinaryDiskCache, queue: DispatchQueue) {
		self.faviconURL = faviconURL
		self.homePageURL = homePageURL
		self.diskCache = diskCache
		self.queue = queue
		self.lastDownloadAttemptDate = Date()
		self.diskKey = faviconURL.md5String

		Task { @MainActor in
			await findFavicon()
		}
	}

	func downloadFaviconIfNeeded() -> Bool {
		// If we don’t have an image, and lastDownloadAttemptDate is a while ago, try again.
		guard iconImage == nil else {
			return false
		}

		let retryInterval: TimeInterval = 30 * 60 // 30 minutes
		if Date().timeIntervalSince(lastDownloadAttemptDate) < retryInterval {
			return false
		}
		lastDownloadAttemptDate = Date()

		Task { @MainActor in
			await findFavicon()
		}

		return true
	}
}

private extension SingleFaviconDownloader {

	func findFavicon() async {
		if let image = await readFromDisk() {
			diskStatus = .onDisk
			iconImage = IconImage(image)
			postDidLoadFaviconNotification()
			return
		}

		diskStatus = .notOnDisk

		if let image = await downloadFavicon() {
			iconImage = IconImage(image)
			postDidLoadFaviconNotification()
		}
	}

	func readFromDisk() async -> RSImage? {
		await withCheckedContinuation { continuation in
			readFromDisk { image in
				continuation.resume(returning: image)
			}
		}
	}

	private func readFromDisk(_ completion: @escaping @MainActor (RSImage?) -> Void) {
		guard diskStatus != .notOnDisk else {
			completion(nil)
			return
		}

		queue.async {
			if let data = self.diskCache[self.diskKey], !data.isEmpty {
				RSImage.image(with: data, imageResultBlock: completion)
				return
			}

			Task { @MainActor in
				completion(nil)
			}
		}
	}

	func saveToDisk(_ data: Data) {
		queue.async {
			do {
				try self.diskCache.setData(data, forKey: self.diskKey)
				Task { @MainActor in
					self.diskStatus = .onDisk
				}
			}
			catch {}
		}
	}

	func downloadFavicon() async -> RSImage? {
		assert(Thread.isMainThread)

		guard let url = URL(string: faviconURL) else {
			return nil
		}

		do {
			let (data, response) = try await Downloader.shared.download(url)
			if let data, !data.isEmpty, let response, response.statusIsOK {
				saveToDisk(data)
				let image = await RSImage.image(data: data)
				return image
			}

		} catch {
			Self.logger.error("Error downloading image at \(url.absoluteString): \(error.localizedDescription)")
		}

		return nil
	}

	func postDidLoadFaviconNotification() {
		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
	}
}
