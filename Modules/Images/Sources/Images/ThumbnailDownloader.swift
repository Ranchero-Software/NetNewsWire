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
	/// The small thumbnail is a square of at most 76pt, which is 228 pixels at 3x.
	private static let smallThumbnailPixelSize = 256
	/// The longest side of a wide image, which fills the timeline’s width before it reaches the height limit.
	private static let largeThumbnailMaxPixelSize = 1200
	/// The large thumbnail is aspect-fit into a box 180pt tall.
	#if os(macOS)
	private static let largeThumbnailMaxPixelHeight = 360
	#else
	private static let largeThumbnailMaxPixelHeight = 540
	#endif
	nonisolated private static let squareBitsPerComponent = 8
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

	@concurrent static func decodedImage(_ data: Data, mode: ThumbnailMode) async throws(ImageDownloadError) -> (image: RSImage, byteCount: Int) {
		switch mode {
		case .small:
			try await decodedSquareImage(data, pixelSize: smallThumbnailPixelSize)
		case .large:
			try await decodedImage(data, maxPixelSize: largeThumbnailMaxPixelSize, maxPixelHeight: largeThumbnailMaxPixelHeight)
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
				let decodedImage = try await Self.decodedImage(data, mode: mode)
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
		let (imageSource, largestFrame) = try significantLargestFrame(data)

		var longestSide = maxPixelSize
		if let maxPixelHeight {
			let isRotated = isRotatedQuarterTurn(imageSource, frameIndex: largestFrame.index)
			let displayedWidth = isRotated ? largestFrame.height : largestFrame.width
			let displayedHeight = isRotated ? largestFrame.width : largestFrame.height
			longestSide = min(maxPixelSize, longestSideAtHeight(maxPixelHeight, width: displayedWidth, height: displayedHeight))
		}

		return try decodedResult(thumbnail(imageSource, frameIndex: largestFrame.index, maxPixelSize: longestSide))
	}

	/// Like `decodedImage(_:maxPixelSize:maxPixelHeight:)`, but decoded so the shorter side is `pixelSize`,
	/// then cropped to a square from the bottom, left, and right, never the top, so faces are less likely to be cropped.
	/// An image with a shorter side under `pixelSize` is cropped at its own size.
	@concurrent static func decodedSquareImage(_ data: Data, pixelSize: Int) async throws(ImageDownloadError) -> (image: RSImage, byteCount: Int) {
		let (imageSource, largestFrame) = try significantLargestFrame(data)

		// The ratio of longer to shorter side is the same rotated or not.
		let shorterSide = min(largestFrame.width, largestFrame.height)
		let longerSide = max(largestFrame.width, largestFrame.height)
		let longestSide = Int((Double(pixelSize) * Double(longerSide) / Double(shorterSide)).rounded(.up))

		let cgImage = try thumbnail(imageSource, frameIndex: largestFrame.index, maxPixelSize: longestSide)
		guard let squareImage = croppedToSquareFromTop(cgImage) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
		}
		return decodedResult(squareImage)
	}
}

private extension ThumbnailDownloader {

	nonisolated static func significantLargestFrame(_ data: Data) throws(ImageDownloadError) -> (imageSource: CGImageSource, largestFrame: (index: Int, width: Int, height: Int)) {
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let largestFrame = RSImage.largestFrame(in: imageSource) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
		}
		guard SignificantImageFilter.hasSignificantDimensions(width: largestFrame.width, height: largestFrame.height) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: false, rejectedPixelSize: (width: largestFrame.width, height: largestFrame.height))
		}
		return (imageSource: imageSource, largestFrame: largestFrame)
	}

	/// In EXIF orientation, with its longest side no more than `maxPixelSize`.
	nonisolated static func thumbnail(_ imageSource: CGImageSource, frameIndex: Int, maxPixelSize: Int) throws(ImageDownloadError) -> CGImage {
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
			kCGImageSourceShouldCacheImmediately: true
		]
		guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, frameIndex, options as CFDictionary) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
		}
		return cgImage
	}

	/// Drawn into its own bitmap, since `CGImage.cropping(to:)` would keep the whole uncropped bitmap in memory.
	/// Wider images lose equal amounts from the left and right. Taller images lose only from the bottom.
	nonisolated static func croppedToSquareFromTop(_ cgImage: CGImage) -> CGImage? {
		guard cgImage.width != cgImage.height else {
			return cgImage
		}
		let side = min(cgImage.width, cgImage.height)
		let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
		guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: squareBitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
			return nil
		}
		// The context’s origin is at the bottom left, so the image’s top edge goes at y == side.
		let drawRect = CGRect(x: -((cgImage.width - side) / 2), y: side - cgImage.height, width: cgImage.width, height: cgImage.height)
		context.draw(cgImage, in: drawRect)
		return context.makeImage()
	}

	nonisolated static func decodedResult(_ cgImage: CGImage) -> (image: RSImage, byteCount: Int) {
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
