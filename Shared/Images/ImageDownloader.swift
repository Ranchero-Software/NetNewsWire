//
//  ImageDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os
import RSCore
import RSWeb
import ActivityLog

extension Notification.Name {
	static let imageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // UserInfoKey.url
}

@MainActor final class ImageDownloader {
	public static let shared = ImageDownloader()

	nonisolated static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImageDownloader")

	nonisolated private let diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private var imageCache = [String: Data]() // url: image
	private var urlsInProgress = Set<String>()
	private var badURLs = Set<String>() // That return a 404 or whatever. Just skip them in the future.

	init() {
		let folder = AppConfig.cacheSubfolder(named: "Images")
		self.diskCache = BinaryDiskCache(folder: folder.path)
		self.queue = DispatchQueue(label: "ImageDownloader serial queue - \(folder.path)")

		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		imageCache.removeAll()
	}

	@objc func handleLowMemory(_ notification: Notification) {
		imageCache.removeAll()
	}

	/// Returns the image data if it's already in the in-memory cache. Otherwise
	/// dispatches an async fetch — disk first, then network — and returns nil;
	/// completion arrives via `.imageDidBecomeAvailable`.
	///
	/// Pass `activityOwner` / `activityKind` (and optionally `activityDetail`)
	/// to have an entry written to the activity log if and only if the fetch
	/// goes to network. Disk-only fetches stay silent.
	@discardableResult
	func image(for url: String, activityOwner: ActivityOwner? = nil, activityKind: ActivityKind? = nil, activityDetail: String? = nil) -> Data? {
		assert(Thread.isMainThread)
		if let data = imageCache[url] {
			return data
		}

		Task { @MainActor in
			await findImage(url, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		}

		return nil
	}
}

private extension ImageDownloader {

	func cacheImage(_ url: String, _ image: Data) {
		assert(Thread.isMainThread)
		imageCache[url] = image
		postImageDidBecomeAvailableNotification(url)
	}

	func findImage(_ url: String, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async {
		guard !urlsInProgress.contains(url) && !badURLs.contains(url) else {
			return
		}
		urlsInProgress.insert(url)

		if let image = await readFromDisk(url: url) {
			cacheImage(url, image)
			urlsInProgress.remove(url)
			return
		}

		// Disk missed — going to network. Produce activity if the caller asked.
		let activityLog = ActivityLog.shared
		if let activityOwner, let activityKind {
			activityLog.createActivity(owner: activityOwner, kind: activityKind, detail: activityDetail)
			activityLog.didStart(activityOwner, kind: activityKind)
		}

		let image = await downloadImage(url)
		if let activityOwner, let activityKind {
			if image != nil {
				activityLog.didComplete(activityOwner, kind: activityKind)
			} else {
				let error = NSError(domain: "ImageDownloader", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
				activityLog.didFail(activityOwner, kind: activityKind, error: error)
			}
		}

		if let image {
			cacheImage(url, image)
		}
		urlsInProgress.remove(url)
	}

	func readFromDisk(url: String) async -> Data? {
		await withCheckedContinuation { continuation in
			readFromDisk(url) { data in
				continuation.resume(returning: data)
			}
		}
	}

	func readFromDisk(_ url: String, _ completion: @escaping @MainActor (Data?) -> Void) {
		queue.async {
			if let data = self.diskCache[self.diskKey(url)], !data.isEmpty {
				DispatchQueue.main.async {
					completion(data)
				}
				return
			}

			DispatchQueue.main.async {
				completion(nil)
			}
		}
	}

	func downloadImage(_ url: String) async -> Data? {
		guard let imageURL = URL(string: url) else {
			return nil
		}

		do {
			let (data, response) = try await Downloader.shared.download(imageURL)

			if let data, !data.isEmpty, let response, response.statusIsOK {
				let scaledData = RSImage.scaledImageData(data, maxPixelSize: RSImage.maxIconPixelSize) ?? data
				saveToDisk(url, scaledData)
				return scaledData
			}

			if let response = response as? HTTPURLResponse, response.statusCode >= HTTPResponseCode.badRequest && response.statusCode <= HTTPResponseCode.notAcceptable {
				badURLs.insert(url)
			}

			return nil
		} catch {
			Self.logger.error("Error downloading image at \(url) \(error.localizedDescription)")
			return nil
		}
	}

	func saveToDisk(_ url: String, _ data: Data) {
		queue.async {
			self.diskCache[self.diskKey(url)] = data
		}
	}

	nonisolated func diskKey(_ url: String) -> String {
		url.md5String
	}

	func postImageDidBecomeAvailableNotification(_ url: String) {
		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .imageDidBecomeAvailable, object: self, userInfo: [UserInfoKey.url: url])
	}
}
