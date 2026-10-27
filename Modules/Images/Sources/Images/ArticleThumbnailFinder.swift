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
/// attachment, and the first significant image in the article’s HTML. Small mode
/// tries them in that order. Large mode tries the article’s image and attachments
/// before the provided thumbnail, which is usually too small to fill the timeline’s width.
///
/// The first three sources are property reads. The HTML is parsed off the main thread
/// by `discoverThumbnailURLs(for:)`, and the results are saved in `ImageMetadataDatabase`,
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

	public static let shared = ArticleThumbnailFinder(metadataDatabase: .shared)

	public static let articleIDsKey = "articleIDs"
	public static let urlKey = "url"

	private let metadataDatabase: ImageMetadataDatabase
	private var htmlThumbnailURLs = [String: String]() // articleID: thumbnailURL
	private var articleIDsWithNoHTMLThumbnail = Set<String>()
	private var articleIDsBeingDiscovered = Set<String>()
	private let imageCache = NSCache<NSString, RSImage>() // See cacheKey
	private var cacheKeysInProgress = Set<String>()
	private var urlsThatFailedToDecode = Set<String>() // So a failure notification can’t lead to the same attempt again

	/// Decoded bitmaps: about 1 MB each in small mode, 2–5 MB in large mode.
	private static let imageCacheByteLimit = 128 * 1024 * 1024
	/// Sized for aspect-fill cropping into a small square.
	private static let smallThumbnailMaxPixelSize = 512
	/// Combined entries in htmlThumbnailURLs and articleIDsWithNoHTMLThumbnail, about 300 bytes each. Past this, both are emptied, and the next discovery reloads its articles from the database.
	private static let maxCachedArticleCount = 20_000

	init(metadataDatabase: ImageMetadataDatabase) {
		self.metadataDatabase = metadataDatabase
		self.imageCache.totalCostLimit = Self.imageCacheByteLimit

		// Not flushed on appDidGoToBackground, which would make thumbnails flash on resume.
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	/// Nil when the image isn’t ready. Starts a download when needed and posts
	/// `.articleThumbnailDidBecomeAvailable` once the image is ready.
	public func thumbnail(for article: Article, mode: Mode) -> RSImage? {
		guard let url = thumbnailURL(for: article, mode: mode) else {
			return nil
		}
		if let image = imageCache.object(forKey: Self.cacheKey(url, mode)) {
			return image
		}

		findImage(url, mode: mode, downloadPriority: .visible, activityDetail: article.title)
		return nil
	}

	/// Gets the thumbnail ready for an article expected to be shown soon.
	/// Its download waits behind thumbnails being shown now.
	public func prefetchThumbnail(for article: Article, mode: Mode) {
		guard let url = thumbnailURL(for: article, mode: mode), imageCache.object(forKey: Self.cacheKey(url, mode)) == nil else {
			return
		}
		findImage(url, mode: mode, downloadPriority: .prefetch, activityDetail: article.title)
	}

	/// Nil when the article has no usable image, or when its HTML hasn’t been checked yet.
	public func thumbnailURL(for article: Article, mode: Mode) -> String? {
		if let providedThumbnailURL = providedThumbnailURL(for: article, mode: mode) {
			return providedThumbnailURL
		}
		guard let htmlThumbnailURL = htmlThumbnailURLs[article.articleID], isUsable(htmlThumbnailURL) else {
			return nil
		}
		return htmlThumbnailURL
	}

	/// Looks for thumbnails in the HTML of articles that have no usable provided image.
	/// Uses results saved in the database, parses the rest off the main thread, and saves those results.
	public func discoverThumbnailURLs(for articles: some Collection<Article>) async {
		if htmlThumbnailURLs.count + articleIDsWithNoHTMLThumbnail.count > Self.maxCachedArticleCount {
			htmlThumbnailURLs.removeAll()
			articleIDsWithNoHTMLThumbnail.removeAll()
		}

		let articlesToCheck = articles.filter(needsHTMLDiscovery)
		guard !articlesToCheck.isEmpty else {
			return
		}

		let articleIDs = articlesToCheck.map(\.articleID)
		articleIDsBeingDiscovered.formUnion(articleIDs)
		defer {
			articleIDsBeingDiscovered.subtract(articleIDs)
		}

		let savedRecords = await metadataDatabase.fetchArticleThumbnails(articleIDs: articleIDs)
		cacheRecords(savedRecords)

		let articleHTMLs = articlesToCheck.filter { !isCached($0.articleID) }.compactMap(ArticleHTML.init)
		var parsedRecords = [ArticleThumbnailRecord]()
		if !articleHTMLs.isEmpty {
			parsedRecords = await Self.parseThumbnailURLs(articleHTMLs)
			cacheRecords(parsedRecords)
			metadataDatabase.saveArticleThumbnails(parsedRecords)
		}

		let foundArticleIDs = Set((savedRecords + parsedRecords).filter { $0.thumbnailURL != nil }.map(\.articleID))
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

		init?(_ article: Article) {
			guard let html = article.contentHTML ?? article.summary, !html.isEmpty else {
				return nil
			}
			self.articleID = article.articleID
			self.html = html
			self.baseURL = article.rawLink ?? article.rawExternalLink
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
			DownloadedImageCache.maxPixelSize
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
		SignificantImageFilter.isSignificant(urlString: urlString, width: nil, height: nil) && !metadataDatabase.recentlyFailed(url: urlString) && !metadataDatabase.isUnsuitableForThumbnail(url: urlString) && !urlsThatFailedToDecode.contains(urlString)
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
			if let thumbnailURL = record.thumbnailURL {
				htmlThumbnailURLs[record.articleID] = thumbnailURL
			} else {
				articleIDsWithNoHTMLThumbnail.insert(record.articleID)
			}
		}
	}

	@concurrent static func parseThumbnailURLs(_ articleHTMLs: [ArticleHTML]) async -> [ArticleThumbnailRecord] {
		articleHTMLs.map { articleHTML in
			let parserData = ParserData(url: articleHTML.baseURL ?? "", data: Data(articleHTML.html.utf8))
			let image = HTMLImageParser.firstSignificantImage(with: parserData)
			return ArticleThumbnailRecord(articleID: articleHTML.articleID, thumbnailURL: image?.urlString)
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
