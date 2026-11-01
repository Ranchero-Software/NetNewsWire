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
import RSWeb
import ActivityLog

extension Notification.Name {
	/// Posted when `findThumbnailURLs(for:)` parses thumbnails from article HTML.
	/// userInfo key: `ArticleThumbnailFinder.articleIDsKey` (`Set<String>`).
	public static let articleThumbnailURLsDidBecomeAvailable = Notification.Name("ArticleThumbnailURLsDidBecomeAvailable")

	/// Posted when a thumbnail image requested by `thumbnail(for:mode:)` is ready.
	/// userInfo key: `ArticleThumbnailFinder.urlKey` (the thumbnail URL).
	public static let articleThumbnailDidBecomeAvailable = Notification.Name("ArticleThumbnailDidBecomeAvailable")

	/// Posted when a thumbnail image fails to download or is rejected for its size.
	/// `thumbnailURL(for:mode:)` now skips that URL, so articles that used it may have a different thumbnail.
	/// userInfo key: `ArticleThumbnailFinder.articleIDsKey` (`Set<String>`, the articles whose `thumbnailURL(for:mode:)` was that URL).
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
/// by `findThumbnailURLs(for:)`, and the results are saved in `ImageDatabase`,
/// so each article’s HTML is parsed once.
///
/// URLs that recently failed to download, and images too small, too narrow, or unreadable
/// to be thumbnails, are skipped, so they fall through to the next source.
///
/// Images are decoded at display size from `DownloadedImageCache`’s copy, off the main thread,
/// a few at a time and newest first, so a fast scroll doesn’t spend time on rows long gone.
@MainActor public final class ArticleThumbnailFinder {

	public enum Mode: String, Sendable, CaseIterable {
		case small
		case large
	}

	public static let shared = ArticleThumbnailFinder(imageDatabase: .shared)

	public static let articleIDsKey = "articleIDs"
	public static let urlKey = "url"

	private let imageDatabase: ImageDatabase
	private var htmlThumbnailURLs = [String: [String]]() // articleID: thumbnailURLs, in document order. Empty when the HTML has none.
	private var articleIDsBeingDiscovered = Set<String>()
	private let imageCache = NSCache<NSString, RSImage>() // See cacheKey
	private let decodeQueue = ThumbnailTaskQueue(maximumRunningCount: maximumConcurrentDecodes, maximumWaitingCount: maximumWaitingDecodes)
	private var decodeKeysInProgress = Set<String>()
	private var urlsThatFailedToDecode = Set<String>() // So a failure notification can’t lead to the same attempt again
	private var chosenThumbnailURLs = [Mode: [String: ChosenThumbnailURL]]() // articleID: the URL thumbnailURL(for:mode:) chose, since large-mode row heights ask for every row

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
	/// HTML images saved per article, so one that fails or is too small falls through to the next.
	nonisolated private static let maxHTMLThumbnailURLsPerArticle = 3
	/// Articles parsed and saved at a time, which also limits how long a save holds the database queue.
	static let parsingBatchSize = 100
	/// Entries in htmlThumbnailURLs, a few hundred bytes each. Past this, it’s emptied, and the next discovery reloads its articles from the database.
	private static let maxCachedArticleCount = 50_000
	/// Entries per mode in chosenThumbnailURLs. Past this, that mode’s entries are emptied.
	private static let maxChosenThumbnailURLCount = 50_000
	private static let maximumConcurrentDecodes = 4
	/// A few screens of thumbnails.
	private static let maximumWaitingDecodes = 60

	init(imageDatabase: ImageDatabase) {
		self.imageDatabase = imageDatabase
		self.imageCache.totalCostLimit = Self.imageCacheByteLimit

		// Not flushed on appDidGoToBackground, which would make thumbnails flash on resume.
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusDidChange(_:)), name: .networkStatusDidChange, object: nil)
	}

	/// False when offline or in Low Data Mode, when thumbnails not already on disk aren’t downloaded.
	public var networkAllowsDownloads: Bool {
		DownloadedImageCache.networkAllowsDownloads
	}

	/// `url` is from `thumbnailURL(for:mode:)`. `articleTitle` is shown in the activity log when the download fails.
	/// Nil when the image isn’t ready. Starts a download when needed and posts
	/// `.articleThumbnailDidBecomeAvailable` once the image is ready.
	public func thumbnail(url: String, mode: Mode, articleTitle: String?) -> RSImage? {
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

	/// Nil when the article has no usable image, or when its HTML hasn’t been checked yet.
	public func thumbnailURL(for article: Article, mode: Mode) -> String? {
		let articleID = article.articleID
		if let chosenThumbnailURL = chosenThumbnailURLs[mode]?[articleID], chosenThumbnailURL.hasSameImages(as: article) {
			return chosenThumbnailURL.thumbnailURL
		}

		let thumbnailURL = providedThumbnailURL(for: article, mode: mode) ?? htmlThumbnailURLs[articleID]?.first { !hasFailed($0) }
		if chosenThumbnailURLs[mode, default: [:]].count >= Self.maxChosenThumbnailURLCount {
			chosenThumbnailURLs[mode] = nil
		}
		chosenThumbnailURLs[mode, default: [:]][articleID] = ChosenThumbnailURL(article, thumbnailURL: thumbnailURL)
		return thumbnailURL
	}

	/// Looks for thumbnails in the HTML of articles that have no usable provided image.
	/// Results saved in the database are ready when this returns, so that rows laid out next can use them.
	/// This blocks until the database has answered.
	/// The rest are parsed off the main thread and saved in batches, in the order given, so the first rows don’t wait for the last.
	/// `.articleThumbnailURLsDidBecomeAvailable` is posted after each batch for those that have thumbnails.
	/// The returned task finishes after the last batch.
	@discardableResult public func findThumbnailURLs(for articles: some Collection<Article>) -> Task<Void, Never> {
		if htmlThumbnailURLs.count > Self.maxCachedArticleCount {
			htmlThumbnailURLs.removeAll()
		}

		let articlesToFind = articles.filter(needsHTMLDiscovery)
		if !articlesToFind.isEmpty {
			cacheRecords(imageDatabase.fetchArticleThumbnailsSync(articleIDs: articlesToFind.map(\.articleID)))
		}

		let articleHTMLs = articlesToFind.filter { !isCached($0.articleID) }.compactMap(ArticleHTML.init)
		let articleIDs = articleHTMLs.map(\.articleID)
		articleIDsBeingDiscovered.formUnion(articleIDs)

		return Task {
			defer {
				articleIDsBeingDiscovered.subtract(articleIDs)
			}
			for batchStart in stride(from: 0, to: articleHTMLs.count, by: Self.parsingBatchSize) {
				let batchEnd = min(batchStart + Self.parsingBatchSize, articleHTMLs.count)
				let parsedRecords = await Self.parseThumbnailURLs(Array(articleHTMLs[batchStart..<batchEnd]))
				cacheRecords(parsedRecords)
				imageDatabase.saveArticleThumbnails(parsedRecords)

				let foundArticleIDs = Set(parsedRecords.filter { !$0.thumbnailURLs.isEmpty }.map(\.articleID))
				if !foundArticleIDs.isEmpty {
					NotificationCenter.default.post(name: .articleThumbnailURLsDidBecomeAvailable, object: self, userInfo: [Self.articleIDsKey: foundArticleIDs])
				}
			}
		}
	}

	func thumbnailDidFail(url: String, error: ImageDownloadError) {
		if error.decodingFailed || error.rejectedPixelSize != nil {
			urlsThatFailedToDecode.insert(url)
		}
		// A transient decoding failure counts, since the row would otherwise keep waiting for an image that isn’t coming.
		if !error.isTransient || error.decodingFailed {
			thumbnailURLDidFail(url)
		}
	}

	/// Forgets the chosen thumbnail URL of each article that used `url`, and posts `.articleThumbnailDownloadDidFail`.
	func thumbnailURLDidFail(_ url: String) {
		var articleIDs = Set<String>()
		for chosenThumbnailURLsForMode in chosenThumbnailURLs.values {
			articleIDs.formUnion(chosenThumbnailURLsForMode.filter { $0.value.thumbnailURL == url }.keys)
		}
		guard !articleIDs.isEmpty else {
			return
		}
		forgetChosenThumbnailURLs(articleIDs)
		NotificationCenter.default.post(name: .articleThumbnailDownloadDidFail, object: self, userInfo: [Self.articleIDsKey: articleIDs])
	}

	// MARK: - Notifications

	@objc func handleLowMemory(_ notification: Notification) {
		imageCache.removeAllObjects()
		chosenThumbnailURLs.removeAll()
	}

	/// What failed to decode may have been a captive portal’s login page, not the image.
	@objc func handleNetworkStatusDidChange(_ notification: Notification) {
		urlsThatFailedToDecode.removeAll()
		chosenThumbnailURLs.removeAll()
	}
}

// MARK: - Private

private extension ArticleThumbnailFinder {

	/// Keeps the article’s image fields, not the article, which would keep its HTML in memory.
	struct ChosenThumbnailURL {
		let rawThumbnailLink: String?
		let rawImageLink: String?
		let attachments: [Attachment]?
		let thumbnailURL: String?

		init(_ article: Article, thumbnailURL: String?) {
			self.rawThumbnailLink = article.rawThumbnailLink
			self.rawImageLink = article.rawImageLink
			self.attachments = article.attachments
			self.thumbnailURL = thumbnailURL
		}

		/// Articles are immutable, so a different instance with the same articleID may have different images.
		func hasSameImages(as article: Article) -> Bool {
			rawThumbnailLink == article.rawThumbnailLink && rawImageLink == article.rawImageLink && attachments == article.attachments
		}
	}

	struct ArticleHTML: Sendable {
		let articleID: String
		let html: String
		let baseURL: URL?

		@MainActor init?(_ article: Article) {
			guard let html = article.contentHTML ?? article.summary, !html.isEmpty else {
				return nil
			}
			self.articleID = article.articleID
			self.html = html
			self.baseURL = article.baseURL
		}
	}

	/// The same URL can be cached at both sizes.
	static func cacheKey(_ url: String, _ mode: Mode) -> NSString {
		"\(mode.rawValue) \(url)" as NSString
	}

	static func maxPixelSize(_ mode: Mode) -> Int {
		switch mode {
		case .small:
			smallThumbnailMaxPixelSize
		case .large:
			largeThumbnailMaxPixelSize
		}
	}

	static func maxPixelHeight(_ mode: Mode) -> Int? {
		switch mode {
		case .small:
			nil
		case .large:
			largeThumbnailMaxPixelHeight
		}
	}

	func findImage(_ url: String, mode: Mode, activityDetail: String?) {
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
				NotificationCenter.default.post(name: .articleThumbnailDidBecomeAvailable, object: self, userInfo: [Self.urlKey: url])
			} catch {
				thumbnailDidFail(url: url, error: error)
			}
		}
	}

	func forgetChosenThumbnailURLs(_ articleIDs: some Sequence<String>) {
		for mode in Mode.allCases {
			for articleID in articleIDs {
				chosenThumbnailURLs[mode]?[articleID] = nil
			}
		}
	}

	func providedThumbnailURL(for article: Article, mode: Mode) -> String? {
		switch mode {
		case .small:
			usableProvidedURL(Self.normalizedURLString(article.rawThumbnailLink)) ?? usableProvidedURL(Self.normalizedURLString(article.rawImageLink)) ?? usableProvidedURL(Self.firstSignificantImageAttachmentURL(article))
		case .large:
			usableProvidedURL(Self.normalizedURLString(article.rawImageLink)) ?? usableProvidedURL(Self.firstSignificantImageAttachmentURL(article)) ?? usableProvidedURL(Self.normalizedURLString(article.rawThumbnailLink))
		}
	}

	func usableProvidedURL(_ urlString: String?) -> String? {
		guard let urlString, !hasFailed(urlString), SignificantImageFilter.isSignificant(urlString: urlString, width: nil, height: nil) else {
			return nil
		}
		return urlString
	}

	/// True when the URL recently failed to download, or its image was too small, too narrow, or unreadable.
	func hasFailed(_ urlString: String) -> Bool {
		imageDatabase.recentlyFailed(url: urlString) || imageDatabase.isUnsuitableForThumbnail(url: urlString) || urlsThatFailedToDecode.contains(urlString)
	}

	func needsHTMLDiscovery(_ article: Article) -> Bool {
		let articleID = article.articleID
		if isCached(articleID) || articleIDsBeingDiscovered.contains(articleID) {
			return false
		}
		// Without HTML results, thumbnailURL is the provided image. Which one is chosen depends on mode, but whether there is one doesn’t.
		return thumbnailURL(for: article, mode: .small) == nil
	}

	func isCached(_ articleID: String) -> Bool {
		htmlThumbnailURLs[articleID] != nil
	}

	func cacheRecords(_ records: [ArticleThumbnailRecord]) {
		forgetChosenThumbnailURLs(records.map(\.articleID))
		for record in records {
			htmlThumbnailURLs[record.articleID] = record.thumbnailURLs
		}
	}

	@concurrent static func parseThumbnailURLs(_ articleHTMLs: [ArticleHTML]) async -> [ArticleThumbnailRecord] {
		articleHTMLs.map { articleHTML in
			let thumbnailURLs = HTMLImageParser.significantImageURLStrings(html: articleHTML.html, baseURL: articleHTML.baseURL, maximumCount: maxHTMLThumbnailURLsPerArticle)
			return ArticleThumbnailRecord(articleID: articleHTML.articleID, thumbnailURLs: thumbnailURLs)
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
