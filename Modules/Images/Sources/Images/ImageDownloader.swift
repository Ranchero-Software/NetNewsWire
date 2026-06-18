//
//  ImageDownloader.swift
//  Images
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
	public static let imageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // userInfo key: "url"
}

public struct ImageDownloadError: Error {
	public let statusCode: Int?
	public let decodingFailed: Bool
	public let isTransient: Bool // No network, DNS issues, timeout, 5xx response, etc.
}

extension ImageDownloadError: LocalizedError {
	public var errorDescription: String? {
		if decodingFailed {
			if let statusCode {
				return "Couldn’t decode image bytes (HTTP \(statusCode))"
			}
			return "Couldn’t decode image bytes"
		}
		guard let statusCode else {
			return isTransient ? "No response" : "Bad URL"
		}
		return "HTTP \(statusCode)"
	}
}

@MainActor public final class ImageDownloader {
	public static let shared = ImageDownloader()

	nonisolated static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ImageDownloader")

	nonisolated private let diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private var imageCache = [String: Data]() // url: image
	private var urlsInProgress = Set<String>()

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

	/// Returns the data if in memory, else dispatches a disk-then-network fetch and returns nil.
	/// Activity log fires only when the fetch reaches the network.
	@discardableResult
	public func image(for url: String, activityOwner: ActivityOwner? = nil, activityKind: ActivityKind? = nil, activityDetail: String? = nil) -> Data? {
		assert(Thread.isMainThread)
		if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
			Self.logger.debug("Skipping non-http(s) URL: \(url)")
			return nil
		}
		if let data = imageCache[url] {
			return data
		}
		if ImageMetadataDatabase.shared.recentlyFailed(url: url) {
			Self.logger.debug("Skipping recently-failed URL: \(url)")
			return nil
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
		guard !urlsInProgress.contains(url) else {
			return
		}
		urlsInProgress.insert(url)

		if let image = await readFromDisk(url: url) {
			cacheImage(url, image)
			urlsInProgress.remove(url)
			return
		}

		let activityLog = ActivityLog.shared
		if let activityOwner, let activityKind {
			activityLog.createActivity(owner: activityOwner, kind: activityKind, detail: activityDetail)
			activityLog.didStart(activityOwner, kind: activityKind)
		}

		do {
			let (image, downloadResponse) = try await downloadImage(url)
			if let activityOwner, let activityKind {
				let message = downloadResponse.data.map(ActivityLog.dataSizeMessage)
				activityLog.didComplete(activityOwner, kind: activityKind, message: message, returnedFromCache: downloadResponse.returnedFromCache)
			}
			cacheImage(url, image)
			ImageMetadataDatabase.shared.clearFailure(url: url)
		} catch {
			if let activityOwner, let activityKind {
				activityLog.didFail(activityOwner, kind: activityKind, error: error)
			}
			if !error.isTransient {
				ImageMetadataDatabase.shared.recordFailure(url: url, statusCode: error.statusCode)
			}
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

	func downloadImage(_ url: String) async throws(ImageDownloadError) -> (Data, DownloadResponse) {
		guard let imageURL = URL(string: url) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: false)
		}

		let downloadResponse: DownloadResponse
		do {
			downloadResponse = try await Downloader.shared.download(imageURL)
		} catch {
			Self.logger.error("Error downloading image at \(url) \(error.localizedDescription)")
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true)
		}

		if let data = downloadResponse.data, !data.isEmpty, let response = downloadResponse.response, response.statusIsOK {
			let scaledData = RSImage.scaledImageData(data, maxPixelSize: RSImage.maxIconPixelSize) ?? data
			saveToDisk(url, scaledData)
			return (scaledData, downloadResponse)
		}

		let statusCode = (downloadResponse.response as? HTTPURLResponse)?.statusCode
		// 2xx with empty / missing body — server said OK but gave us no image bytes.
		if let response = downloadResponse.response, response.statusIsOK {
			throw ImageDownloadError(statusCode: statusCode, decodingFailed: true, isTransient: false)
		}
		let isTransient = statusCode.map { (500...599).contains($0) } ?? true
		throw ImageDownloadError(statusCode: statusCode, decodingFailed: false, isTransient: isTransient)
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
		NotificationCenter.default.post(name: .imageDidBecomeAvailable, object: self, userInfo: ["url": url])
	}
}
