//
//  SingleFaviconDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os
import ActivityLog
import RSCore
import RSWeb

extension Notification.Name {
	public static let DidLoadFavicon = Notification.Name("DidLoadFaviconNotification")
}

/// Reads from disk, falls back to network. Posts `.DidLoadFavicon` on both
/// success and persistent failure.
@MainActor public final class SingleFaviconDownloader {
	private enum DiskStatus {
		case unknown, notOnDisk, onDisk
	}

	public let faviconURL: String
	public let homePageURL: String?

	public var iconImage: IconImage?

	/// The persistent failure, if any. Nil after success or for transient failures.
	public private(set) var error: ImageDownloadError?

	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SingleFaviconDownloader")

	private let diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private let diskKey: String

	private var lastDownloadAttemptDate: Date
	private var diskStatus = DiskStatus.unknown

	public init(faviconURL: String, homePageURL: String?, diskCache: BinaryDiskCache, queue: DispatchQueue) {
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

	public func downloadFaviconIfNeeded() -> Bool {
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
			error = nil
			postDidLoadFaviconNotification()
			return
		}

		diskStatus = .notOnDisk

		do {
			let image = try await downloadFavicon()
			iconImage = IconImage(image)
			error = nil
		} catch {
			self.error = error.isTransient ? nil : error
		}
		postDidLoadFaviconNotification()
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
			} catch {}
		}
	}

	func downloadFavicon() async throws(ImageDownloadError) -> RSImage {
		assert(Thread.isMainThread)

		guard let url = URL(string: faviconURL) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: false)
		}

		let activityLog = ActivityLog.shared
		let kind = ActivityKind.downloadFavicon(faviconURL: faviconURL)
		activityLog.createActivity(owner: .faviconDownloader, kind: kind, detail: homePageURL)
		activityLog.didStart(.faviconDownloader, kind: kind)

		let downloadResponse: DownloadResponse
		do {
			downloadResponse = try await Downloader.shared.download(url)
		} catch {
			Self.logger.error("Error downloading image at \(url.absoluteString): \(error.localizedDescription)")
			activityLog.didFail(.faviconDownloader, kind: kind, error: error)
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true)
		}

		if let data = downloadResponse.data, !data.isEmpty, let response = downloadResponse.response, response.statusIsOK {
			let scaledData = RSImage.scaledImageData(data, maxPixelSize: RSImage.maxIconPixelSize) ?? data
			let image = await RSImage.image(data: scaledData)
			guard let image else {
				let responseStatusCode = (response as? HTTPURLResponse)?.statusCode
				let error = ImageDownloadError(statusCode: responseStatusCode, decodingFailed: true, isTransient: false)
				activityLog.didFail(.faviconDownloader, kind: kind, error: error)
				throw error
			}
			saveToDisk(scaledData)
			activityLog.didComplete(.faviconDownloader, kind: kind, message: ActivityLog.dataSizeMessage(data), returnedFromCache: downloadResponse.returnedFromCache)
			return image
		}

		let statusCode = (downloadResponse.response as? HTTPURLResponse)?.statusCode
		// 2xx with empty / missing body — server said OK but gave us no image bytes.
		if let response = downloadResponse.response, response.statusIsOK {
			let error = ImageDownloadError(statusCode: statusCode, decodingFailed: true, isTransient: false)
			activityLog.didFail(.faviconDownloader, kind: kind, error: error)
			throw error
		}
		let isTransient = statusCode.map { (500...599).contains($0) } ?? true
		let error = ImageDownloadError(statusCode: statusCode, decodingFailed: false, isTransient: isTransient)
		activityLog.didFail(.faviconDownloader, kind: kind, error: error)
		throw error
	}

	func postDidLoadFaviconNotification() {
		assert(Thread.isMainThread)
		NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
	}
}
