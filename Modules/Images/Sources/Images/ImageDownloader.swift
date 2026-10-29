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
import ActivityLog

extension Notification.Name {
	public static let imageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // userInfo key: "url"
	public static let imageDownloadDidFail = Notification.Name("ImageDownloadDidFailNotification") // userInfo key: "url". Not posted for transient failures.
}

public struct ImageDownloadError: Error {
	public let statusCode: Int?
	public let decodingFailed: Bool
	public let isTransient: Bool // No network, DNS issues, timeout, 5xx, 429, or 408 response, etc.
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

/// Makes feed icons, favicons, and avatars from `DownloadedImageCache`’s copy, and caches them in memory.
/// The public API is the same whether the copy is on disk or has to be downloaded.
@MainActor public final class ImageDownloader {

	public static let shared = ImageDownloader()

	nonisolated static private let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ImageDownloader")

	private let imageCache = NSCache<NSString, NSData>() // url: image
	private var urlsInProgress = Set<String>()

	private init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleDownloadedImageDidChange(_:)), name: .downloadedImageDidChange, object: nil)
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		imageCache.removeAllObjects()
	}

	@objc func handleLowMemory(_ notification: Notification) {
		imageCache.removeAllObjects()
	}

	/// Made again even when not in memory, since icons made from the old copy may be cached elsewhere.
	@objc func handleDownloadedImageDidChange(_ notification: Notification) {
		guard let url = notification.userInfo?[DownloadedImageCache.urlKey] as? String else {
			return
		}
		imageCache.removeObject(forKey: url as NSString)
		Task { @MainActor in
			await findImage(url, activityOwner: nil, activityKind: nil, activityDetail: nil)
		}
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
		if ImageDatabase.shared.recentlyFailed(url: url) {
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

	func findImage(_ url: String, activityOwner: ActivityOwner?, activityKind: ActivityKind?, activityDetail: String?) async {
		guard !urlsInProgress.contains(url) else {
			return
		}
		urlsInProgress.insert(url)
		defer {
			urlsInProgress.remove(url)
		}

		do {
			let storedData = try await DownloadedImageCache.shared.imageData(for: url, downloadPriority: nil, checksForUpdates: true, activityOwner: activityOwner, activityKind: activityKind, activityDetail: activityDetail)
			let data = await Self.scaledImageData(storedData, maxPixelSize: RSImage.maxIconPixelSize)
			cacheImage(url, data)
		} catch {
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

	@concurrent static func scaledImageData(_ data: Data, maxPixelSize: Int) async -> Data {
		RSImage.scaledImageData(data, maxPixelSize: maxPixelSize) ?? data
	}
}
