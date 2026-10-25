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

extension Notification.Name {
	/// Posted when `discoverThumbnailURLs(for:)` finds thumbnails in article HTML.
	/// userInfo key: `ArticleThumbnailFinder.articleIDsKey` (`Set<String>`).
	public static let articleThumbnailURLsDidBecomeAvailable = Notification.Name("ArticleThumbnailURLsDidBecomeAvailable")
}

/// Finds the URL of the image that stands for an article in the timeline.
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
/// URLs that recently failed to download are skipped, so a dead or rejected image
/// falls through to the next source.
@MainActor public final class ArticleThumbnailFinder {

	public enum Mode: Sendable {
		case small
		case large
	}

	public static let shared = ArticleThumbnailFinder(metadataDatabase: .shared)

	public static let articleIDsKey = "articleIDs"

	private let metadataDatabase: ImageMetadataDatabase
	private var htmlThumbnailURLs = [String: String]() // articleID: thumbnailURL
	private var articleIDsWithNoHTMLThumbnail = Set<String>()
	private var articleIDsBeingDiscovered = Set<String>()

	init(metadataDatabase: ImageMetadataDatabase) {
		self.metadataDatabase = metadataDatabase
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
		SignificantImageFilter.isSignificant(urlString: urlString, width: nil, height: nil) && !metadataDatabase.recentlyFailed(url: urlString)
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
