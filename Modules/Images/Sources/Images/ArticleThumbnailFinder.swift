//
//  ArticleThumbnailFinder.swift
//  Images
//
//  Created by Brent Simmons on 10/25/26.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import ImageIO
import Articles
import RSCore
import RSParser
import ActivityLog

extension Notification.Name {
	/// Posted when `discoverThumbnailURLs(for:)` finds thumbnails in article HTML.
	/// userInfo key: `ArticleThumbnailFinder.articleIDsKey` (`Set<String>`).
	public static let articleThumbnailURLsDidBecomeAvailable = Notification.Name("ArticleThumbnailURLsDidBecomeAvailable")

	/// Posted when a thumbnail image requested by `thumbnail(for:mode:)` is ready.
	/// userInfo key: `ArticleThumbnailFinder.urlKey` (the thumbnail URL).
	public static let articleThumbnailDidBecomeAvailable = Notification.Name("ArticleThumbnailDidBecomeAvailable")

	/// Posted when a thumbnail image fails to download or is rejected for its size.
	/// `thumbnailURL(for:mode:)` now skips that URL, so articles that used it may have a different thumbnail.
	/// userInfo key: `ArticleThumbnailFinder.urlKey` (the failed URL).
	public static let articleThumbnailDownloadDidFail = Notification.Name("ArticleThumbnailDownloadDidFail")
}

/// Finds the image that stands for an article in the timeline.
///
/// Sources: the provided thumbnail, the article’s image, the first significant image
/// attachment, and the first few significant images in the article’s HTML. Small mode
/// tries them in that order. Large mode tries the article’s image and attachments
/// before the provided thumbnail, which is usually too small to fill the timeline’s width.
///
/// The first three sources are property reads. The HTML is parsed off the main thread
/// by `discoverThumbnailURLs(for:)`, and the results are saved in `ImageDatabase`,
/// so each article’s HTML is parsed once.
///
/// URLs that recently failed to download, and images too small, too narrow, or unreadable
/// to be thumbnails, are skipped, so they fall through to the next source.
///
/// Images are decoded at display size from `DownloadedImageCache`’s copy, off the main thread.
@MainActor public final class ArticleThumbnailFinder {

	public enum Mode: Sendable {
		case small
		case large
	}

	public static let shared = ArticleThumbnailFinder(imageDatabase: .shared)

	public static let articleIDsKey = "articleIDs"
	public static let urlKey = "url"

	private let imageDatabase: ImageDatabase
	private var htmlThumbnailURLs = [String: [String]]() // articleID: thumbnailURLs, in document order
	private var articleIDsWithNoHTMLThumbnail = Set<String>()
	private var articleIDsBeingDiscovered = Set<String>()
	private let imageCache = NSCache<NSString, RSImage>() // See cacheKey
	private var cacheKeysInProgress = Set<String>()
	private var urlsThatFailedToDecode = Set<String>() // So a failure notification can’t lead to the same attempt again

	/// Decoded bitmaps: about 1 MB each in small mode, 2–5 MB in large mode.
	private static let imageCacheByteLimit = 128 * 1024 * 1024
	/// Sized for aspect-fill cropping into a small square.
	private static let smallThumbnailMaxPixelSize = 512
	/// Sized to fill the timeline’s width.
	private static let largeThumbnailMaxPixelSize = 1200
	/// HTML images saved per article, so one that fails or is too small falls through to the next.
	nonisolated private static let maxHTMLThumbnailURLsPerArticle = 3
	/// Combined entries in htmlThumbnailURLs and articleIDsWithNoHTMLThumbnail, a few hundred bytes each. Past this, both are emptied, and the next discovery reloads its articles from the database.
	private static let maxCachedArticleCount = 50_000

	init(imageDatabase: ImageDatabase) {
		self.imageDatabase = imageDatabase
		self.imageCache.totalCostLimit = Self.imageCacheByteLimit

		// Not flushed on appDidGoToBackground, which would make thumbnails flash on resume.
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	/// False when offline or in Low Data Mode, when thumbnails not already on disk aren’t downloaded.
	public var networkAllowsDownloads: Bool {
		DownloadLimiter.networkAllowsDownloads
	}

	/// `url` is from `thumbnailURL(for:mode:)`. `articleTitle` is shown in the activity log.
	/// Nil when the image isn’t ready. Starts a download when needed and posts
	/// `.articleThumbnailDidBecomeAvailable` once the image is ready.
	public func thumbnail(url: String, mode: Mode, articleTitle: String?) -> RSImage? {
		if let image = imageCache.object(forKey: Self.cacheKey(url, mode)) {
			return image
		}
		findImage(url, mode: mode, downloadPriority: .visible, activityDetail: articleTitle)
		return nil
	}

	/// Gets a thumbnail ready for an article expected to be shown soon.
	/// Its download waits behind thumbnails being shown now.
	public func prefetchThumbnail(url: String, mode: Mode, articleTitle: String?) {
		guard imageCache.object(forKey: Self.cacheKey(url, mode)) == nil else {
			return
		}
		findImage(url, mode: mode, downloadPriority: .prefetch, activityDetail: articleTitle)
	}

	/// The image as downloaded, for the article view, which shows the thumbnail image at full size.
	/// Shares the timeline’s copy and any download in progress, so the image is downloaded once.
	/// A download starts right away rather than waiting behind timeline downloads.
	public func fullSizeImageData(url: String, articleTitle: String?) async throws(ImageDownloadError) -> Data {
		try await DownloadedImageCache.shared.imageData(for: url, downloadPriority: nil, checksForUpdates: false, activityOwner: .thumbnailDownloader, activityKind: .downloadThumbnail(imageURL: url), activityDetail: articleTitle)
	}

	/// Nil when the article has no usable image, or when its HTML hasn’t been checked yet.
	public func thumbnailURL(for article: Article, mode: Mode) -> String? {
		if let providedThumbnailURL = providedThumbnailURL(for: article, mode: mode) {
			return providedThumbnailURL
		}
		return htmlThumbnailURLs[article.articleID]?.first(where: isUsable)
	}

	/// Looks for thumbnails in the HTML of articles that have no usable provided image.
	/// Uses results saved in the database, parses the rest off the main thread, and saves those results.
	public func discoverThumbnailURLs(for articles: some Collection<Article>) async {
		if htmlThumbnailURLs.count + articleIDsWithNoHTMLThumbnail.count > Self.maxCachedArticleCount {
			htmlThumbnailURLs.removeAll()
			articleIDsWithNoHTMLThumbnail.removeAll()
		}

		let articleHTMLs = articles.filter(needsHTMLDiscovery).compactMap(ArticleHTML.init)
		guard !articleHTMLs.isEmpty else {
			return
		}

		let articleIDs = articleHTMLs.map(\.articleID)
		articleIDsBeingDiscovered.formUnion(articleIDs)
		defer {
			articleIDsBeingDiscovered.subtract(articleIDs)
		}

		let savedRecords = await imageDatabase.fetchArticleThumbnails(articleIDs: articleIDs)
		cacheRecords(savedRecords)

		let articleHTMLsToParse = articleHTMLs.filter { !isCached($0.articleID) }
		var parsedRecords = [ArticleThumbnailRecord]()
		if !articleHTMLsToParse.isEmpty {
			parsedRecords = await Self.parseThumbnailURLs(articleHTMLsToParse)
			cacheRecords(parsedRecords)
			imageDatabase.saveArticleThumbnails(parsedRecords)
		}

		let foundArticleIDs = Set((savedRecords + parsedRecords).filter { !$0.thumbnailURLs.isEmpty }.map(\.articleID))
		if !foundArticleIDs.isEmpty {
			NotificationCenter.default.post(name: .articleThumbnailURLsDidBecomeAvailable, object: self, userInfo: [Self.articleIDsKey: foundArticleIDs])
		}
	}

	// MARK: - Notifications

	@objc func handleLowMemory(_ notification: Notification) {
		imageCache.removeAllObjects()
	}
}

// MARK: - Private

private extension ArticleThumbnailFinder {

	struct ArticleHTML: Sendable {
		let articleID: String
		let html: String
		let baseURL: String?

		@MainActor init?(_ article: Article) {
			guard let html = article.contentHTML ?? article.summary, !html.isEmpty else {
				return nil
			}
			self.articleID = article.articleID
			self.html = html
			self.baseURL = article.baseURL?.absoluteString
		}
	}

	/// The same URL can be cached at both sizes.
	static func cacheKey(_ url: String, _ mode: Mode) -> NSString {
		"\(mode) \(url)" as NSString
	}

	static func maxPixelSize(_ mode: Mode) -> Int {
		switch mode {
		case .small:
			smallThumbnailMaxPixelSize
		case .large:
			largeThumbnailMaxPixelSize
		}
	}

	func findImage(_ url: String, mode: Mode, downloadPriority: DownloadPriority, activityDetail: String?) {
		let cacheKey = Self.cacheKey(url, mode)
		guard !cacheKeysInProgress.contains(cacheKey as String) else {
			if downloadPriority == .visible {
				DownloadedImageCache.shared.prioritizeDownload(for: url)
			}
			return
		}
		cacheKeysInProgress.insert(cacheKey as String)

		Task {
			defer {
				cacheKeysInProgress.remove(cacheKey as String)
			}
			do throws(ImageDownloadError) {
				let data = try await DownloadedImageCache.shared.imageData(for: url, downloadPriority: downloadPriority, checksForUpdates: false, activityOwner: .thumbnailDownloader, activityKind: .downloadThumbnail(imageURL: url), activityDetail: activityDetail)
				let decodedImage = try await Self.decodedImage(data, maxPixelSize: Self.maxPixelSize(mode))
				imageCache.setObject(decodedImage.image, forKey: cacheKey, cost: decodedImage.byteCount)
				NotificationCenter.default.post(name: .articleThumbnailDidBecomeAvailable, object: self, userInfo: [Self.urlKey: url])
			} catch {
				if error.decodingFailed || error.rejectedPixelSize != nil {
					urlsThatFailedToDecode.insert(url)
				}
				if !error.isTransient {
					NotificationCenter.default.post(name: .articleThumbnailDownloadDidFail, object: self, userInfo: [Self.urlKey: url])
				}
			}
		}
	}

	func providedThumbnailURL(for article: Article, mode: Mode) -> String? {
		let thumbnailURL = Self.normalizedURLString(article.rawThumbnailLink)
		let imageURL = Self.normalizedURLString(article.rawImageLink)
		let attachmentURL = Self.firstSignificantImageAttachmentURL(article)

		let candidates = switch mode {
		case .small:
			[thumbnailURL, imageURL, attachmentURL]
		case .large:
			[imageURL, attachmentURL, thumbnailURL]
		}

		for candidate in candidates {
			if let candidate, isUsable(candidate) {
				return candidate
			}
		}
		return nil
	}

	func isUsable(_ urlString: String) -> Bool {
		SignificantImageFilter.isSignificant(urlString: urlString, width: nil, height: nil) && !imageDatabase.recentlyFailed(url: urlString) && !imageDatabase.isUnsuitableForThumbnail(url: urlString) && !urlsThatFailedToDecode.contains(urlString)
	}

	func needsHTMLDiscovery(_ article: Article) -> Bool {
		let articleID = article.articleID
		if isCached(articleID) || articleIDsBeingDiscovered.contains(articleID) {
			return false
		}
		// Which source is chosen depends on mode, but whether there is one doesn’t.
		return providedThumbnailURL(for: article, mode: .small) == nil
	}

	func isCached(_ articleID: String) -> Bool {
		htmlThumbnailURLs[articleID] != nil || articleIDsWithNoHTMLThumbnail.contains(articleID)
	}

	func cacheRecords(_ records: [ArticleThumbnailRecord]) {
		for record in records {
			if !record.thumbnailURLs.isEmpty {
				htmlThumbnailURLs[record.articleID] = record.thumbnailURLs
			} else {
				articleIDsWithNoHTMLThumbnail.insert(record.articleID)
			}
		}
	}

	@concurrent static func parseThumbnailURLs(_ articleHTMLs: [ArticleHTML]) async -> [ArticleThumbnailRecord] {
		articleHTMLs.map { articleHTML in
			let parserData = ParserData(url: articleHTML.baseURL ?? "", data: Data(articleHTML.html.utf8))
			let images = HTMLImageParser.significantImages(with: parserData, maximumCount: maxHTMLThumbnailURLsPerArticle)
			return ArticleThumbnailRecord(articleID: articleHTML.articleID, thumbnailURLs: images.map(\.urlString))
		}
	}

	static func firstSignificantImageAttachmentURL(_ article: Article) -> String? {
		guard let attachments = article.attachments else {
			return nil
		}
		for attachment in attachments where attachment.displayMedium == .image {
			if SignificantImageFilter.isSignificant(urlString: attachment.url, width: attachment.width, height: attachment.height) {
				return attachment.url
			}
		}
		return nil
	}

	/// Encodes spaces, as `Article.imageLink` does.
	static func normalizedURLString(_ link: String?) -> String? {
		guard let link, !link.isEmpty else {
			return nil
		}
		return URL.encodeSpacesIfNeeded(link)?.absoluteString ?? link
	}
}

// MARK: - Decoding

extension ArticleThumbnailFinder {

	/// Decodes now, at display size and in EXIF orientation, so drawing the image in the timeline
	/// doesn’t decode it on the main thread. Throws when the image is unreadable, too small, or too narrow.
	@concurrent static func decodedImage(_ data: Data, maxPixelSize: Int) async throws(ImageDownloadError) -> (image: RSImage, byteCount: Int) {
		guard let pixelSize = RSImage.largestFramePixelSize(data) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
		}
		guard SignificantImageFilter.hasSignificantDimensions(width: pixelSize.width, height: pixelSize.height) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: false, isTransient: false, rejectedPixelSize: pixelSize)
		}

		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
			kCGImageSourceShouldCacheImmediately: true
		]
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil), let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
			throw ImageDownloadError(statusCode: nil, decodingFailed: true, isTransient: false)
		}

		let byteCount = cgImage.bytesPerRow * cgImage.height
		#if os(macOS)
		return (image: NSImage(cgImage: cgImage, size: .zero), byteCount: byteCount)
		#else
		return (image: UIImage(cgImage: cgImage), byteCount: byteCount)
		#endif
	}
}
