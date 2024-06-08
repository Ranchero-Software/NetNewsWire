//
//  SingleFaviconDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os.log
import Web
import FoundationExtras
import Core

// The image may be on disk already. If not, download it.
// Post .DidLoadFavicon notification once it’s in memory.

extension Notification.Name {
	static let DidLoadFavicon = Notification.Name("DidLoadFaviconNotification")
}

@MainActor final class SingleFaviconDownloader {

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

	private var diskKey: String {
		return faviconURL.md5String
	}

	init(faviconURL: String, homePageURL: String?, diskCache: BinaryDiskCache) {

		self.faviconURL = faviconURL
		self.homePageURL = homePageURL
		self.diskCache = diskCache
		self.lastDownloadAttemptDate = Date()

		Task {
			await findFavicon()
		}
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

		Task {
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

		guard diskStatus != .notOnDisk else {
			return nil
		}
		guard let data = await diskCache[self.diskKey], !data.isEmpty else {
			return nil
		}

		return await RSImage.image(with: data)
	}

	func saveToDisk(_ data: Data) {

		Task.detached {
			try? await self.diskCache.setData(data, forKey: self.diskKey)

			Task { @MainActor in
				self.diskStatus = .onDisk
			}
		}
	}

	func downloadFavicon() async -> RSImage? {

		guard let url = URL(string: faviconURL) else {
			return nil
		}

		do {
			let downloadData = try await DownloadWithCacheManager.shared.download(url)

			let data = downloadData.data
			let response = downloadData.response

			if let data, !data.isEmpty, let response, response.statusIsOK {
				saveToDisk(data)
				return await RSImage.image(with: data)
			}

		} catch {
			os_log(.info, log: self.log, "Error downloading image at %@: %@.", url.absoluteString, error.localizedDescription)
		}

		return nil
	}

	func postDidLoadFaviconNotification() {

		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
	}
}
