//
//  ArticleThumbnailFinderTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import Testing
import Articles
import RSWeb
@testable import Images

/// Swift Testing also has an `Attachment` type.
private typealias ArticleAttachment = Articles.Attachment

@MainActor @Suite struct ArticleThumbnailFinderTests {

	@Test func smallModePrefersThumbnailAndLargeModePrefersImage() throws {
		let finder = ArticleThumbnailFinder(imageDatabase: ImageDatabase(databasePath: ":memory:"))
		let attachment = try #require(ArticleAttachment(url: "https://example.com/attachment.jpg", mimeType: "image/jpeg", title: nil, sizeInBytes: nil, durationInSeconds: nil, width: 1200, height: 800, medium: nil))
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg", attachments: [attachment])

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/thumbnail.jpg")
		#expect(finder.thumbnailURL(for: article, mode: .large) == "https://example.com/image.jpg")
	}

	@Test func largeModePrefersHTMLImageToBloggerSquareThumbnail() {
		let finder = ArticleThumbnailFinder(imageDatabase: ImageDatabase(databasePath: ":memory:"))
		let bloggerThumbnailURL = "https://blogger.googleusercontent.com/img/b/photo/s72-w424-h353-c/202610211751.jpg"
		let bloggerImageURL = "https://blogger.googleusercontent.com/img/b/photo/w424-h353/202610211751.jpg"
		let article = makeArticle(contentHTML: "<p><img src=\"\(bloggerImageURL)\"></p>", thumbnailURL: bloggerThumbnailURL)
		let articleWithNoHTMLImage = makeArticle(articleID: "2", contentHTML: "<p>No images.</p>", thumbnailURL: bloggerThumbnailURL)

		#expect(finder.thumbnailURL(for: article, mode: .large) == bloggerImageURL)
		#expect(finder.thumbnailURL(for: article, mode: .small) == bloggerThumbnailURL)
		#expect(finder.thumbnailURL(for: articleWithNoHTMLImage, mode: .large) == bloggerThumbnailURL)
	}

	@Test func failedImageFallsThroughToNextSource() {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg")

		imageDatabase.recordFailure(url: "https://example.com/thumbnail.jpg")

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/image.jpg")
	}

	@Test func insignificantDimensionsFallThroughButAreNotAFailure() {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/logo.png")

		imageDatabase.saveDownloadedImage(DownloadedImageRecord(url: "https://example.com/logo.png", pixelSize: (width: 48, height: 48), conditionalGetInfo: nil, nextCheck: Date(), isIcon: false))

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/image.jpg")
		#expect(!imageDatabase.recentlyFailed(url: "https://example.com/logo.png"))
	}

	@Test func htmlThumbnailIsDiscovered() async {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let html = """
		<p><a href="https://twitter.com/intent/tweet?url=x"><img src="/share/twitter.png"></a></p>
		<p><img src="/uploads/photo.jpg" width="640" height="480"></p>
		<p><img src="/uploads/second-photo.jpg" width="640" height="480"></p>
		"""
		let articleWithImage = makeArticle(articleID: "1", contentHTML: html)
		let articleWithoutImage = makeArticle(articleID: "2", contentHTML: "<p>No images.</p>")

		await finder.findThumbnailURLs(for: [articleWithImage, articleWithoutImage])
		#expect(finder.thumbnailURL(for: articleWithImage, mode: .small) == "https://example.com/uploads/photo.jpg")
		#expect(finder.thumbnailURL(for: articleWithoutImage, mode: .small) == nil)

		imageDatabase.recordFailure(url: "https://example.com/uploads/photo.jpg")
		finder.thumbnailURLDidFail("https://example.com/uploads/photo.jpg")
		#expect(finder.thumbnailURL(for: articleWithImage, mode: .small) == "https://example.com/uploads/second-photo.jpg")
	}

	@Test func failedProvidedImageFallsBackToHTMLThumbnail() async {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let article = makeArticle(contentHTML: #"<p><img src="/uploads/photo.jpg" width="640" height="480"></p>"#, thumbnailURL: "https://example.com/thumbnail.jpg")

		await finder.findThumbnailURLs(for: [article])
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/thumbnail.jpg")

		imageDatabase.recordFailure(url: "https://example.com/thumbnail.jpg")
		finder.thumbnailURLDidFail("https://example.com/thumbnail.jpg")
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/uploads/photo.jpg")
	}

	@Test func htmlThumbnailIsParsedOnCacheMissAndAfterCacheIsEmptied() {
		let finder = ArticleThumbnailFinder(imageDatabase: ImageDatabase(databasePath: ":memory:"))
		let article = makeArticle(contentHTML: #"<p><img src="/uploads/photo.jpg" width="640" height="480"></p>"#)
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/uploads/photo.jpg")

		finder.handleAppDidGoToBackground(Notification(name: .appDidGoToBackground))
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/uploads/photo.jpg")
	}

	@Test func nonImageResponseMovesToNextSourceUntilNetworkChanges() {
		let finder = ArticleThumbnailFinder(imageDatabase: ImageDatabase(databasePath: ":memory:"))
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg")
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/thumbnail.jpg")

		finder.thumbnailDidFail(url: "https://example.com/thumbnail.jpg", error: ImageDownloadError(statusCode: 200, decodingFailed: true, isTransient: true))
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/image.jpg")

		finder.handleNetworkStatusDidChange(Notification(name: .networkStatusDidChange))
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/thumbnail.jpg")
	}

	@Test func newArticleInstanceReusesChosenURLUnlessItsImagesChanged() {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg")
		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/thumbnail.jpg")

		// A failure with no notification shows whether the choice was made again.
		imageDatabase.recordFailure(url: "https://example.com/thumbnail.jpg")

		let sameImages = makeArticle(contentHTML: "<p>Edited.</p>", imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg")
		#expect(finder.thumbnailURL(for: sameImages, mode: .small) == "https://example.com/thumbnail.jpg")

		let differentImages = makeArticle(imageURL: "https://example.com/new-image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg")
		#expect(finder.thumbnailURL(for: differentImages, mode: .small) == "https://example.com/new-image.jpg")
	}
}

// MARK: - Helpers

private func makeArticle(articleID: String = "1", contentHTML: String? = nil, imageURL: String? = nil, thumbnailURL: String? = nil, attachments: [ArticleAttachment]? = nil) -> Article {
	let status = ArticleStatus(articleID: articleID, read: false, starred: false, dateArrived: Date())
	return Article(accountID: "account", articleID: articleID, feedID: "feed", uniqueID: articleID, title: nil, contentHTML: contentHTML, contentText: nil, markdown: nil, url: "https://example.com/posts/\(articleID)", externalURL: nil, summary: nil, imageURL: imageURL, thumbnailURL: thumbnailURL, datePublished: nil, dateModified: nil, authors: nil, attachments: attachments, status: status)
}
