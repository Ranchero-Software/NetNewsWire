//
//  ArticleThumbnailFinderTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import Testing
import Articles
@testable import Images

/// Swift Testing also has an `Attachment` type.
private typealias ArticleAttachment = Articles.Attachment

@MainActor @Suite struct ArticleThumbnailFinderTests {

	@Test func smallModePrefersThumbnailAndLargeModePrefersImage() throws {
		let finder = ArticleThumbnailFinder(metadataDatabase: ImageMetadataDatabase(databasePath: ":memory:"))
		let attachment = try #require(ArticleAttachment(url: "https://example.com/attachment.jpg", mimeType: "image/jpeg", title: nil, sizeInBytes: nil, durationInSeconds: nil, width: 1200, height: 800, medium: nil))
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg", attachments: [attachment])

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/thumbnail.jpg")
		#expect(finder.thumbnailURL(for: article, mode: .large) == "https://example.com/image.jpg")
	}

	@Test func failedImageFallsThroughToNextSource() {
		let metadataDatabase = ImageMetadataDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(metadataDatabase: metadataDatabase)
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg")

		metadataDatabase.recordFailure(url: "https://example.com/thumbnail.jpg", statusCode: 404)

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/image.jpg")
	}

	@Test func insignificantDimensionsFallThroughButAreNotAFailure() {
		let metadataDatabase = ImageMetadataDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(metadataDatabase: metadataDatabase)
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/logo.png")

		metadataDatabase.recordInsignificantDimensions(url: "https://example.com/logo.png")

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/image.jpg")
		#expect(!metadataDatabase.recentlyFailed(url: "https://example.com/logo.png"))
	}

	@Test func htmlThumbnailIsDiscoveredAndSaved() async {
		let metadataDatabase = ImageMetadataDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(metadataDatabase: metadataDatabase)
		let html = """
		<p><a href="https://twitter.com/intent/tweet?url=x"><img src="/share/twitter.png"></a></p>
		<p><img src="/uploads/photo.jpg" width="640" height="480"></p>
		"""
		let articleWithImage = makeArticle(articleID: "1", contentHTML: html)
		let articleWithoutImage = makeArticle(articleID: "2", contentHTML: "<p>No images.</p>")

		#expect(finder.thumbnailURL(for: articleWithImage, mode: .small) == nil)

		await finder.discoverThumbnailURLs(for: [articleWithImage, articleWithoutImage])
		#expect(finder.thumbnailURL(for: articleWithImage, mode: .small) == "https://example.com/uploads/photo.jpg")
		#expect(finder.thumbnailURL(for: articleWithoutImage, mode: .small) == nil)

		let records = await metadataDatabase.fetchArticleThumbnails(articleIDs: ["1", "2"])
		#expect(Set(records.map(\.articleID)) == ["1", "2"])
		#expect(records.first { $0.articleID == "1" }?.thumbnailURL == "https://example.com/uploads/photo.jpg")
		#expect(records.first { $0.articleID == "2" }?.thumbnailURL == nil)
	}
}

// MARK: - Helpers

private func makeArticle(articleID: String = "1", contentHTML: String? = nil, imageURL: String? = nil, thumbnailURL: String? = nil, attachments: [ArticleAttachment]? = nil) -> Article {
	let status = ArticleStatus(articleID: articleID, read: false, starred: false, dateArrived: Date())
	return Article(accountID: "account", articleID: articleID, feedID: "feed", uniqueID: articleID, title: nil, contentHTML: contentHTML, contentText: nil, markdown: nil, url: "https://example.com/posts/\(articleID)", externalURL: nil, summary: nil, imageURL: imageURL, thumbnailURL: thumbnailURL, datePublished: nil, dateModified: nil, authors: nil, attachments: attachments, status: status)
}
