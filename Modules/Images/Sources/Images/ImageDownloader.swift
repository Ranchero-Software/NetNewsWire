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

/// Makes images at one size from `DownloadedImageCache`’s copy, and caches them in memory.
/// The public API is the same whether the copy is on disk or has to be downloaded.
@MainActor public final class ImageDownloader {

	/// Feed icons, favicons, and avatars.
	public static let shared = ImageDownloader(configuration: Configuration(maxPixelSize: RSImage.maxIconPixelSize, format: .png, memoryCacheByteLimit: 0, requiresSignificantDimensions: false, usesDownloadLimiter: false))

	/// Timeline thumbnails, sized for aspect-fill cropping into a small square.
	public static let thumbnails = ImageDownloader(configuration: Configuration(maxPixelSize: thumbnailMaxPixelSize, format: .jpeg(compressionQuality: thumbnailCompressionQuality), memoryCacheByteLimit: thumbnailMemoryCacheByteLimit, requiresSignificantDimensions: true, usesDownloadLimiter: true))

	/// Timeline thumbnails, sized to span the timeline’s width.
	public static let largeThumbnails = ImageDownloader(configuration: Configuration(maxPixelSize: DownloadedImageCache.maxPixelSize, format: .jpeg(compressionQuality: thumbnailCompressionQuality), memoryCacheByteLimit: thumbnailMemoryCacheByteLimit, requiresSignificantDimensions: true, usesDownloadLimiter: true))

	struct Configuration: Sendable {
		let maxPixelSize: Int
		let format: ScaledImageFormat
		let memoryCacheByteLimit: Int // 0 means no limit
		let requiresSignificantDimensions: Bool // Checked against the stored image’s pixel dimensions
		let usesDownloadLimiter: Bool
	}

	private static let thumbnailMaxPixelSize = 512
	private static let thumbnailCompressionQuality = 0.8
	private static let thumbnailMemoryCacheByteLimit = 32 * 1024 * 1024

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ImageDownloader")

	private let configuration: Configuration
	private let imageCache = NSCache<NSString, NSData>() // url: image
	private var urlsInProgress = Set<String>()

	init(configuration: Configuration) {
		self.configuration = configuration
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

	/// Returns the data if in memory, else makes it from `DownloadedImageCache`’s copy and returns nil.
	/// Posts `.imageDidBecomeAvailable` when it’s ready.
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

	func findImage(_ url: String, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async {
		guard !urlsInProgress.contains(url) else {
			return
		}
		urlsInProgress.insert(url)
		defer {
			urlsInProgress.remove(url)
		}

		do {
			let storedData = try await DownloadedImageCache.shared.imageData(for: url, usesDownloadLimiter: configuration.usesDownloadLimiter, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
			let data = try await Self.scaledImageData(storedData, configuration: configuration)
			cacheImage(url, data)
		} catch {
			if error.rejectedPixelSize != nil {
				ImageMetadataDatabase.shared.recordInsignificantDimensions(url: url)
			}
			if !error.isTransient {
				NotificationCenter.default.post(name: .imageDownloadDidFail, object: self, userInfo: ["url": url])
			}
		}
	}

	func cacheImage(_ url: String, _ image: Data) {
		assert(Thread.isMainThread)
		imageCache.setObject(image as NSData, forKey: url as NSString, cost: image.count)
		NotificationCenter.default.post(name: .imageDidBecomeAvailable, object: self, userInfo: ["url": url])
	}
}

// MARK: - Image Processing

extension ImageDownloader {

	/// Resizes off the main thread. Throws when `requiresSignificantDimensions` and the image is
	/// unreadable, too small, or too narrow.
	@concurrent static func scaledImageData(_ data: Data, configuration: Configuration) async throws(ImageDownloadError) -> Data {
		if configuration.requiresSignificantDimensions {
			guard let pixelSize = RSImage.largestFramePixelSize(data) else {
				throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
			}
			guard SignificantImageFilter.hasSignificantDimensions(width: pixelSize.width, height: pixelSize.height) else {
				throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: false, rejectedPixelSize: pixelSize)
			}
		}
		return RSImage.scaledImageData(data, maxPixelSize: configuration.maxPixelSize, format: configuration.format) ?? data
	}
}
