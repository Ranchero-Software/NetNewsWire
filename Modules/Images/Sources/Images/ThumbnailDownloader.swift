//
//  ThumbnailDownloader.swift
//  Images
//
//  Created by Brent Simmons on 11/3/26.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import ImageIO
import RSCore
import RSParser
import RSWeb
import ActivityLog

extension Notification.Name {
	/// Posted when a thumbnail image requested by `thumbnail(url:mode:articleTitle:)` is ready.
	/// userInfo key: `ThumbnailDownloader.urlKey`.
	public static let thumbnailDidBecomeAvailable = Notification.Name("ThumbnailDidBecomeAvailable")

	/// Posted when a thumbnail image fails to download or decode, or is rejected for its size.
	/// userInfo keys: `ThumbnailDownloader.urlKey` and `ThumbnailDownloader.errorKey` (`ImageDownloadError`).
	public static let thumbnailDownloadDidFail = Notification.Name("ThumbnailDownloadDidFail")
}

public enum ThumbnailMode: String, Sendable, CaseIterable {
	case small
	case large
}

/// Downloads and decodes the timeline’s thumbnail images, and caches them in memory.
///
/// Images are decoded at display size from `DownloadedImageCache`’s copy, off the main thread,
/// a few at a time and newest first, so a fast scroll doesn’t spend time on rows long gone.
@MainActor public final class ThumbnailDownloader {

	public static let shared = ThumbnailDownloader()

	public static let urlKey = "url"
	public static let errorKey = "error"

	private let imageCache = NSCache<NSString, RSImage>() // See cacheKey
	private let decodeQueue = ThumbnailTaskQueue(maximumRunningCount: maximumConcurrentDecodes, maximumWaitingCount: maximumWaitingDecodes)
	private var decodeKeysInProgress = Set<String>()

	/// Decoded bitmaps: about 0.25 MB each in small mode, at most about 2.5 MB in large mode.
	#if os(macOS)
	private static let imageCacheByteLimit = 128 * 1024 * 1024
	#else
	private static let imageCacheByteLimit = 64 * 1024 * 1024
	#endif
	/// The small thumbnail is aspect-fit into a box of at most 76pt, which is 228 pixels at 3x.
	private static let smallThumbnailMaxPixelSize = 256
	/// The longest side of a wide image, which fills the timeline’s width before it reaches the height limit.
	private static let largeThumbnailMaxPixelSize = 1200
	/// The large thumbnail is aspect-fit into a box 180pt tall.
	#if os(macOS)
	private static let largeThumbnailMaxPixelHeight = 360
	#else
	private static let largeThumbnailMaxPixelHeight = 540
	#endif
	private static let maximumConcurrentDecodes = 4
	/// A few screens of thumbnails.
	private static let maximumWaitingDecodes = 60

	private init() {
		self.imageCache.totalCostLimit = Self.imageCacheByteLimit

		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	/// False when offline or in Low Data Mode, when thumbnails not already on disk aren’t downloaded.
	public var networkAllowsDownloads: Bool {
		DownloadedImageCache.networkAllowsDownloads
	}

	/// `url` is from `ArticleThumbnailFinder.thumbnailURL(for:mode:)`. `articleTitle` is shown in the activity log when the download fails.
	/// Nil when the image isn’t ready. Starts a download when needed and posts
	/// `.thumbnailDidBecomeAvailable` once the image is ready.
	public func thumbnail(url: String, mode: ThumbnailMode, articleTitle: String?) -> RSImage? {
		if let image = imageCache.object(forKey: Self.cacheKey(url, mode)) {
			DownloadedImageCache.shared.imageWasUsed(url, checksForUpdates: false)
			return image
		}
		findImage(url, mode: mode, activityDetail: articleTitle)
		return nil
	}

	/// The image as downloaded, for the article view, which shows the thumbnail image at full size.
	/// Shares the timeline’s copy and any download in progress, so the image is downloaded once.
	/// A download starts right away rather than waiting behind timeline downloads.
	public func fullSizeImageData(url: String, articleTitle: String?) async throws(ImageDownloadError) -> Data {
		try await DownloadedImageCache.shared.imageData(for: url, usesDownloadQueue: false, checksForUpdates: false, activityOwner: .thumbnailDownloader, activityKind: .downloadThumbnail(imageURL: url), activityDetail: articleTitle)
	}

	// MARK: - Notifications

	/// The cache is kept when the app goes to the background, since emptying it would make thumbnails flash on resume.
	@objc func handleLowMemory(_ notification: Notification) {
		imageCache.removeAllObjects()
	}
}

private extension ThumbnailDownloader {

	/// The same URL can be cached at both sizes.
	static func cacheKey(_ url: String, _ mode: ThumbnailMode) -> NSString {
		"\(mode.rawValue) \(url)" as NSString
	}

	static func maxPixelSize(_ mode: ThumbnailMode) -> Int {
		switch mode {
		case .small:
			smallThumbnailMaxPixelSize
		case .large:
			largeThumbnailMaxPixelSize
		}
	}

	static func maxPixelHeight(_ mode: ThumbnailMode) -> Int? {
		switch mode {
		case .small:
			nil
		case .large:
			largeThumbnailMaxPixelHeight
		}
	}

	func findImage(_ url: String, mode: ThumbnailMode, activityDetail: String?) {
		let cacheKey = Self.cacheKey(url, mode)
		let decodeKey = cacheKey as String
		guard !decodeKeysInProgress.contains(decodeKey) else {
			DownloadedImageCache.shared.prioritizeDownload(for: url)
			decodeQueue.prioritize(key: decodeKey)
			return
		}
		decodeKeysInProgress.insert(decodeKey)

		Task {
			defer {
				decodeKeysInProgress.remove(decodeKey)
			}
			do throws(ImageDownloadError) {
				let data = try await DownloadedImageCache.shared.imageData(for: url, usesDownloadQueue: true, checksForUpdates: false, activityOwner: .thumbnailDownloader, activityKind: .downloadThumbnail(imageURL: url), activityDetail: activityDetail)
				guard await decodeQueue.waitForTurn(key: decodeKey) != .dropped else {
					return
				}
				defer {
					decodeQueue.taskDidFinish()
				}
				let decodedImage = try await Self.decodedImage(data, maxPixelSize: Self.maxPixelSize(mode), maxPixelHeight: Self.maxPixelHeight(mode))
				imageCache.setObject(decodedImage.image, forKey: cacheKey, cost: decodedImage.byteCount)
				NotificationCenter.default.post(name: .thumbnailDidBecomeAvailable, object: self, userInfo: [Self.urlKey: url])
			} catch {
				NotificationCenter.default.post(name: .thumbnailDownloadDidFail, object: self, userInfo: [Self.urlKey: url, Self.errorKey: error])
			}
		}
	}
}

// MARK: - Decoding

extension ThumbnailDownloader {

	/// Decodes now, at display size and in EXIF orientation, so drawing the image in the timeline
	/// doesn’t decode it on the main thread. Throws when the image is unreadable, too small, or too narrow.
	/// For a multi-image file such as ICO, the largest frame is the one checked and decoded.
	/// With a `maxPixelHeight`, the image is also no taller than that as displayed.
	@concurrent static func decodedImage(_ data: Data, maxPixelSize: Int, maxPixelHeight: Int?) async throws(ImageDownloadError) -> (image: RSImage, byteCount: Int) {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let largestFrame = RSImage.largestFrame(in: imageSource) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
		}
		guard SignificantImageFilter.hasSignificantDimensions(width: largestFrame.width, height: largestFrame.height) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: false, rejectedPixelSize: (width: largestFrame.width, height: largestFrame.height))
		}

		var longestSide = maxPixelSize
		if let maxPixelHeight {
			let isRotated = isRotatedQuarterTurn(imageSource, frameIndex: largestFrame.index)
			let displayedWidth = isRotated ? largestFrame.height : largestFrame.width
			let displayedHeight = isRotated ? largestFrame.width : largestFrame.height
			longestSide = min(maxPixelSize, longestSideAtHeight(maxPixelHeight, width: displayedWidth, height: displayedHeight))
		}

		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: longestSide,
			kCGImageSourceShouldCacheImmediately: true
		]
		guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, largestFrame.index, options as CFDictionary) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
		}

		let byteCount = cgImage.bytesPerRow * cgImage.height
		#if os(macOS)
		return (image: NSImage(cgImage: cgImage, size: .zero), byteCount: byteCount)
		#else
		return (image: UIImage(cgImage: cgImage), byteCount: byteCount)
		#endif
	}

	/// True when EXIF orientation swaps the frame’s width and height.
	nonisolated private static func isRotatedQuarterTurn(_ imageSource: CGImageSource, frameIndex: Int) -> Bool {
		let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, frameIndex, nil) as NSDictionary?
		guard let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32, let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) else {
			return false
		}
		switch orientation {
		case .left, .leftMirrored, .right, .rightMirrored:
			return true
		case .up, .upMirrored, .down, .downMirrored:
			return false
		}
	}

	nonisolated private static func longestSideAtHeight(_ displayedHeight: Int, width: Int, height: Int) -> Int {
		guard width > height else {
			return displayedHeight
		}
		return Int((Double(displayedHeight) * Double(width) / Double(height)).rounded(.up))
	}
}
