//
//  ArticleThumbnailFinderTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Articles
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

	@Test func failedImageFallsThroughToNextSource() {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/thumbnail.jpg")

		imageDatabase.recordFailure(url: "https://example.com/thumbnail.jpg", statusCode: 404)

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/image.jpg")
	}

	@Test func insignificantDimensionsFallThroughButAreNotAFailure() {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let article = makeArticle(imageURL: "https://example.com/image.jpg", thumbnailURL: "https://example.com/logo.png")

		imageDatabase.saveDownloadedImage(DownloadedImageRecord(url: "https://example.com/logo.png", byteCount: 1024, pixelSize: (width: 48, height: 48), conditionalGetInfo: nil, nextCheck: Date()))

		#expect(finder.thumbnailURL(for: article, mode: .small) == "https://example.com/image.jpg")
		#expect(!imageDatabase.recentlyFailed(url: "https://example.com/logo.png"))
	}

	@Test func htmlThumbnailIsDiscoveredAndSaved() async {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let finder = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		let html = """
		<p><a href="https://twitter.com/intent/tweet?url=x"><img src="/share/twitter.png"></a></p>
		<p><img src="/uploads/photo.jpg" width="640" height="480"></p>
		<p><img src="/uploads/second-photo.jpg" width="640" height="480"></p>
		"""
		let articleWithImage = makeArticle(articleID: "1", contentHTML: html)
		let articleWithoutImage = makeArticle(articleID: "2", contentHTML: "<p>No images.</p>")

		#expect(finder.thumbnailURL(for: articleWithImage, mode: .small) == nil)

		await finder.discoverThumbnailURLs(for: [articleWithImage, articleWithoutImage])
		#expect(finder.thumbnailURL(for: articleWithImage, mode: .small) == "https://example.com/uploads/photo.jpg")
		#expect(finder.thumbnailURL(for: articleWithoutImage, mode: .small) == nil)

		let records = await imageDatabase.fetchArticleThumbnails(articleIDs: ["1", "2"])
		#expect(Set(records.map(\.articleID)) == ["1", "2"])
		#expect(records.first { $0.articleID == "1" }?.thumbnailURLs == ["https://example.com/uploads/photo.jpg", "https://example.com/uploads/second-photo.jpg"])
		#expect(records.first { $0.articleID == "2" }?.thumbnailURLs == [])

		imageDatabase.recordFailure(url: "https://example.com/uploads/photo.jpg", statusCode: 404)
		finder.thumbnailURLDidFail("https://example.com/uploads/photo.jpg")
		#expect(finder.thumbnailURL(for: articleWithImage, mode: .small) == "https://example.com/uploads/second-photo.jpg")
	}

	@Test func savedHTMLThumbnailIsLoadedWithoutDiscovery() async {
		let imageDatabase = ImageDatabase(databasePath: ":memory:")
		let article = makeArticle(contentHTML: #"<p><img src="/uploads/photo.jpg" width="640" height="480"></p>"#)
		await ArticleThumbnailFinder(imageDatabase: imageDatabase).discoverThumbnailURLs(for: [article])

		let finderAfterRelaunch = ArticleThumbnailFinder(imageDatabase: imageDatabase)
		#expect(finderAfterRelaunch.thumbnailURL(for: article, mode: .large) == nil)

		finderAfterRelaunch.loadSavedThumbnailURLs(for: [article])
		#expect(finderAfterRelaunch.thumbnailURL(for: article, mode: .large) == "https://example.com/uploads/photo.jpg")
	}

	@Test func thumbnailTooSmallIsRejected() async throws {
		let smallImageData = try #require(jpegData(width: 48, height: 48))

		await #expect {
			_ = try await ArticleThumbnailFinder.decodedImage(smallImageData, maxPixelSize: 512)
		} throws: { error in
			(error as? ImageDownloadError)?.rejectedPixelSize?.width == 48
		}
	}

	@Test func thumbnailIsDecodedInEXIFOrientation() async throws {
		let rotatedImageData = try #require(jpegData(width: 400, height: 200, orientation: .right))

		let decodedImage = try await ArticleThumbnailFinder.decodedImage(rotatedImageData, maxPixelSize: 512)
		#expect(decodedImage.image.size == CGSize(width: 200, height: 400))
	}
}

// MARK: - Helpers

private func makeArticle(articleID: String = "1", contentHTML: String? = nil, imageURL: String? = nil, thumbnailURL: String? = nil, attachments: [ArticleAttachment]? = nil) -> Article {
	let status = ArticleStatus(articleID: articleID, read: false, starred: false, dateArrived: Date())
	return Article(accountID: "account", articleID: articleID, feedID: "feed", uniqueID: articleID, title: nil, contentHTML: contentHTML, contentText: nil, markdown: nil, url: "https://example.com/posts/\(articleID)", externalURL: nil, summary: nil, imageURL: imageURL, thumbnailURL: thumbnailURL, datePublished: nil, dateModified: nil, authors: nil, attachments: attachments, status: status)
}

private func jpegData(width: Int, height: Int, orientation: CGImagePropertyOrientation = .up) -> Data? {
	guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
		return nil
	}
	context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
	context.fill(CGRect(x: 0, y: 0, width: width, height: height))
	guard let cgImage = context.makeImage(), let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
		return nil
	}
	let properties = [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
	CGImageDestinationAddImage(destination, cgImage, properties)
	guard CGImageDestinationFinalize(destination) else {
		return nil
	}
	return mutableData as Data
}
