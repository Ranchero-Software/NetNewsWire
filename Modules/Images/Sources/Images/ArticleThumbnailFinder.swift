//
//  ArticleThumbnailFinder.swift
//  Images
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import Articles
import RSCore
import RSParser
import RSWeb
import ActivityLog

extension Notification.Name {
	/// Posted when a thumbnail image fails to download or is rejected for its size.
	/// `thumbnailURL(for:mode:)` now skips that URL, so articles that used it may have a different thumbnail.
	/// userInfo key: `ArticleThumbnailFinder.articleIDsKey` (`Set<String>`, the articles whose `thumbnailURL(for:mode:)` was that URL).
	public static let articleThumbnailDownloadDidFail = Notification.Name("ArticleThumbnailDownloadDidFail")
}

/// Finds the image that stands for an article in the timeline.
///
/// Sources: the provided thumbnail, the article’s image, the first significant image
/// attachment, and the first few significant images in the article’s HTML. Small mode
/// tries them in that order. Large mode tries the provided thumbnail last, since it’s usually
/// too small to fill the timeline’s width. Blogger’s, for instance, are 72-pixel square crops.
///
/// The first three sources are property reads. The HTML is parsed off the main thread by
/// `findThumbnailURLs(for:)` at fetch time, or by `thumbnailURL(for:mode:)` on a cache miss.
/// The results are cached in memory until the app goes to the background or memory is low.
/// Parsing 1,000 articles takes about 0.036 seconds on an M1 Max in a release build, measured
/// on 8,660 real articles: median 0.000018 seconds and 2,463 bytes of HTML per article.
///
/// URLs that recently failed to download, and images too small, too narrow, or unreadable
/// to be thumbnails, are skipped, so they fall through to the next source.
///
/// `ThumbnailDownloader` downloads and decodes the images.
@MainActor public final class ArticleThumbnailFinder {

	public static let shared = ArticleThumbnailFinder(imageDatabase: .shared)

	public static let articleIDsKey = "articleIDs"

	private let imageDatabase: ImageDatabase
	private var htmlThumbnailURLs = [String: [String]]() // articleID: thumbnailURLs, in document order. Empty when the HTML has none.
	private var urlsThatFailedToDecode = Set<String>() // So a failure notification can’t lead to the same attempt again
	private var chosenThumbnailURLs = [ThumbnailMode: [String: ChosenThumbnailURL]]() // articleID: the URL thumbnailURL(for:mode:) chose, since large-mode row heights ask for every row

	/// HTML images kept per article, so one that fails or is too small falls through to the next.
	nonisolated private static let maxHTMLThumbnailURLsPerArticle = 3
	/// Entries per mode in chosenThumbnailURLs. Past this, that mode’s entries are emptied.
	private static let maxChosenThumbnailURLCount = 50_000

	init(imageDatabase: ImageDatabase) {
		self.imageDatabase = imageDatabase

		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleNetworkStatusDidChange(_:)), name: .networkStatusDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleThumbnailDownloadDidFail(_:)), name: .thumbnailDownloadDidFail, object: nil)
	}

	/// Nil when the article has no usable image. Parses the article’s HTML when it isn’t cached.
	public func thumbnailURL(for article: Article, mode: ThumbnailMode) -> String? {
		let articleID = article.articleID
		if let chosenThumbnailURL = chosenThumbnailURLs[mode]?[articleID], chosenThumbnailURL.hasSameImages(as: article) {
			return chosenThumbnailURL.thumbnailURL
		}

		let thumbnailURL = providedThumbnailURL(for: article, mode: mode) ?? cachedOrParsedHTMLThumbnailURLs(for: article).first { !hasFailed($0) } ?? usableProvidedURL(Self.normalizedURLString(article.rawThumbnailLink))
		if chosenThumbnailURLs[mode, default: [:]].count >= Self.maxChosenThumbnailURLCount {
			chosenThumbnailURLs[mode] = nil
		}
		chosenThumbnailURLs[mode, default: [:]][articleID] = ChosenThumbnailURL(article, thumbnailURL: thumbnailURL)
		return thumbnailURL
	}

	/// Parses, off the main thread, the HTML of articles that have no usable provided image and no cached result.
	public func findThumbnailURLs(for articles: some Collection<Article>) async {
		var articleHTMLs = [ArticleHTML]()
		for article in articles where needsHTMLParsing(article) {
			if let articleHTML = ArticleHTML(article) {
				articleHTMLs.append(articleHTML)
			} else {
				htmlThumbnailURLs[article.articleID] = []
			}
		}
		guard !articleHTMLs.isEmpty else {
			return
		}

		let parsedThumbnailURLs = await Self.parsedThumbnailURLs(articleHTMLs)
		htmlThumbnailURLs.merge(parsedThumbnailURLs) { _, parsedURLs in parsedURLs }
	}

	/// Empties the results of parsing article HTML, which `thumbnailURL(for:mode:)` parses again as needed.
	public func emptyHTMLThumbnailCache() {
		htmlThumbnailURLs.removeAll()
		chosenThumbnailURLs.removeAll()
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
		emptyHTMLThumbnailCache()
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		emptyHTMLThumbnailCache()
	}

	/// What failed to decode may have been a captive portal’s login page, not the image.
	@objc func handleNetworkStatusDidChange(_ notification: Notification) {
		urlsThatFailedToDecode.removeAll()
		chosenThumbnailURLs.removeAll()
	}

	@objc func handleThumbnailDownloadDidFail(_ notification: Notification) {
		guard let url = notification.userInfo?[ThumbnailDownloader.urlKey] as? String, let error = notification.userInfo?[ThumbnailDownloader.errorKey] as? ImageDownloadError else {
			return
		}
		thumbnailDidFail(url: url, error: error)
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

		/// In document order. Empty when the HTML has no usable image.
		nonisolated func parsedThumbnailURLs() -> [String] {
			HTMLImageParser.significantImageURLStrings(html: html, baseURL: baseURL, maximumCount: maxHTMLThumbnailURLsPerArticle)
		}
	}

	func forgetChosenThumbnailURLs(_ articleIDs: some Sequence<String>) {
		for mode in ThumbnailMode.allCases {
			for articleID in articleIDs {
				chosenThumbnailURLs[mode]?[articleID] = nil
			}
		}
	}

	/// The provided image to use ahead of images in the HTML.
	func providedThumbnailURL(for article: Article, mode: ThumbnailMode) -> String? {
		switch mode {
		case .small:
			usableProvidedURL(Self.normalizedURLString(article.rawThumbnailLink)) ?? usableProvidedURL(Self.normalizedURLString(article.rawImageLink)) ?? usableProvidedURL(Self.firstSignificantImageAttachmentURL(article))
		case .large:
			usableProvidedURL(Self.normalizedURLString(article.rawImageLink)) ?? usableProvidedURL(Self.firstSignificantImageAttachmentURL(article))
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

	func needsHTMLParsing(_ article: Article) -> Bool {
		guard htmlThumbnailURLs[article.articleID] == nil else {
			return false
		}
		// Large mode uses the HTML for any article that small mode does, and for those with only a provided thumbnail.
		return providedThumbnailURL(for: article, mode: .large) == nil
	}

	func cachedOrParsedHTMLThumbnailURLs(for article: Article) -> [String] {
		if let thumbnailURLs = htmlThumbnailURLs[article.articleID] {
			return thumbnailURLs
		}
		let thumbnailURLs = ArticleHTML(article)?.parsedThumbnailURLs() ?? []
		htmlThumbnailURLs[article.articleID] = thumbnailURLs
		return thumbnailURLs
	}

	/// articleID: thumbnailURLs
	@concurrent static func parsedThumbnailURLs(_ articleHTMLs: [ArticleHTML]) async -> [String: [String]] {
		var thumbnailURLs = [String: [String]]()
		for articleHTML in articleHTMLs {
			thumbnailURLs[articleHTML.articleID] = articleHTML.parsedThumbnailURLs()
		}
		return thumbnailURLs
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
