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
import RSParser
import RSWeb
import ActivityLog

extension Notification.Name {
	public static let imageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // userInfo key: "url"
	public static let imageDownloadDidFail = Notification.Name("ImageDownloadDidFailNotification") // userInfo key: "url". Not posted for transient failures.
}

public struct ImageDownloadError: Error {
	public let statusCode: Int?
	public let decodingFailed: Bool
	public let isTransient: Bool // No network, DNS issues, timeout, 5xx response, etc.
	public let rejectedPixelSize: (width: Int, height: Int)? // Too small or too narrow to be a thumbnail

	init(statusCode: Int?, decodingFailed: Bool, isTransient: Bool, rejectedPixelSize: (width: Int, height: Int)? = nil) {
		self.statusCode = statusCode
		self.decodingFailed = decodingFailed
		self.isTransient = isTransient
		self.rejectedPixelSize = rejectedPixelSize
	}
}

extension ImageDownloadError: LocalizedError {
	public var errorDescription: String? {
		if let rejectedPixelSize {
			return "Image too small or too narrow (\(rejectedPixelSize.width)×\(rejectedPixelSize.height))"
		}
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

/// Downloads images, resizes them, and caches them in memory and on disk.
/// Each instance has its own disk cache folder, since the disk key is the URL alone.
@MainActor public final class ImageDownloader {

	/// Feed icons, favicons, and avatars.
	public static let shared = ImageDownloader(configuration: Configuration(cacheFolderName: "Images", maxPixelSize: RSImage.maxIconPixelSize, format: .png, memoryCacheByteLimit: 0, requiresSignificantDimensions: false, downloadLimiter: nil))

	/// Timeline thumbnails, sized for aspect-fill cropping into a small square.
	public static let thumbnails = ImageDownloader(configuration: Configuration(cacheFolderName: "Thumbnails", maxPixelSize: thumbnailMaxPixelSize, format: .jpeg(compressionQuality: thumbnailCompressionQuality), memoryCacheByteLimit: thumbnailMemoryCacheByteLimit, requiresSignificantDimensions: true, downloadLimiter: thumbnailDownloadLimiter))

	/// Timeline thumbnails, sized to span the timeline’s width.
	public static let largeThumbnails = ImageDownloader(configuration: Configuration(cacheFolderName: "LargeThumbnails", maxPixelSize: largeThumbnailMaxPixelSize, format: .jpeg(compressionQuality: thumbnailCompressionQuality), memoryCacheByteLimit: thumbnailMemoryCacheByteLimit, requiresSignificantDimensions: true, downloadLimiter: thumbnailDownloadLimiter))

	struct Configuration: Sendable {
		let cacheFolderName: String
		let maxPixelSize: Int
		let format: ScaledImageFormat
		let memoryCacheByteLimit: Int // 0 means no limit
		let requiresSignificantDimensions: Bool // Checked against the downloaded image’s real pixel dimensions
		let downloadLimiter: DownloadLimiter?
	}

	private static let thumbnailMaxPixelSize = 512
	private static let largeThumbnailMaxPixelSize = 1200
	private static let thumbnailCompressionQuality = 0.8
	private static let thumbnailMemoryCacheByteLimit = 32 * 1024 * 1024
	private static let maximumConcurrentThumbnailDownloads = 4

	/// Shared by both thumbnail downloaders.
	private static let thumbnailDownloadLimiter = DownloadLimiter(maximumConcurrentDownloads: maximumConcurrentThumbnailDownloads)

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ImageDownloader")

	private let configuration: Configuration
	nonisolated private let diskCache: BinaryDiskCache
	private let queue: DispatchQueue
	private let imageCache = NSCache<NSString, NSData>() // url: image
	private var urlsInProgress = Set<String>()

	init(configuration: Configuration) {
		self.configuration = configuration
		let folder = AppConfig.cacheSubfolder(named: configuration.cacheFolderName)
		self.diskCache = BinaryDiskCache(folder: folder.path)
		self.queue = DispatchQueue(label: "ImageDownloader serial queue - \(folder.path)")
		self.imageCache.totalCostLimit = configuration.memoryCacheByteLimit

		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		imageCache.removeAllObjects()
	}

	@objc func handleLowMemory(_ notification: Notification) {
		imageCache.removeAllObjects()
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
		if let data = imageCache.object(forKey: url as NSString) {
			return data as Data
		}
		if ImageMetadataDatabase.shared.recentlyFailed(url: url) {
			Self.logger.debug("Skipping recently-failed URL: \(url)")
			return nil
		}
		if configuration.requiresSignificantDimensions && ImageMetadataDatabase.shared.recentlyLackedSignificantDimensions(url: url) {
			Self.logger.debug("Skipping thumbnail URL with insignificant dimensions: \(url)")
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
		imageCache.setObject(image as NSData, forKey: url as NSString, cost: image.count)
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

		if let downloadLimiter = configuration.downloadLimiter {
			guard downloadLimiter.networkAllowsDownloads else {
				urlsInProgress.remove(url)
				return
			}
			await downloadLimiter.waitForTurn()
		}
		await downloadImageFromNetwork(url, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
		configuration.downloadLimiter?.downloadDidFinish()
		urlsInProgress.remove(url)
	}

	func downloadImageFromNetwork(_ url: String, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async {
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
				if error.rejectedPixelSize != nil {
					ImageMetadataDatabase.shared.recordInsignificantDimensions(url: url)
				} else {
					ImageMetadataDatabase.shared.recordFailure(url: url, statusCode: error.statusCode)
				}
				NotificationCenter.default.post(name: .imageDownloadDidFail, object: self, userInfo: ["url": url])
			}
		}
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
			downloadResponse = try await Downloader.shared.download(imageURL, userAgentStyle: .browser)
		} catch {
			Self.logger.error("Error downloading image at \(url) \(error.localizedDescription)")
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: true)
		}

		let statusCode = (downloadResponse.response as? HTTPURLResponse)?.statusCode
		if let data = downloadResponse.data, !data.isEmpty, let response = downloadResponse.response, response.statusIsOK {
			let scaledData = try await Self.scaledImageData(data, statusCode: statusCode, configuration: configuration)
			saveToDisk(url, scaledData)
			return (scaledData, downloadResponse)
		}

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

// MARK: - Image Processing

extension ImageDownloader {

	/// Resizes off the main thread. Throws when `requiresSignificantDimensions` and the image is
	/// unreadable, too small, or too narrow, so it’s recorded as a failure, as a 404 would be.
	@concurrent static func scaledImageData(_ data: Data, statusCode: Int?, configuration: Configuration) async throws(ImageDownloadError) -> Data {
		if configuration.requiresSignificantDimensions {
			guard let pixelSize = RSImage.largestFramePixelSize(data) else {
				throw ImageDownloadError(statusCode: statusCode, decodingFailed: true, isTransient: false)
			}
			guard SignificantImageFilter.hasSignificantDimensions(width: pixelSize.width, height: pixelSize.height) else {
				throw ImageDownloadError(statusCode: statusCode, decodingFailed: false, isTransient: false, rejectedPixelSize: pixelSize)
			}
		}
		return RSImage.scaledImageData(data, maxPixelSize: configuration.maxPixelSize, format: configuration.format) ?? data
	}
}
