//
//  ArticleUpdateTests.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 9/16/26.
//

import Foundation
import Testing
import Articles
import RSParser
import ArticlesDatabase

/// Every refresh diffs incoming articles against stored ones and writes only
/// what changed. These tests cover the diff: a changed field persists, and an
/// unchanged article is not reported as updated.
///
/// The articles cache returns the incoming article rather than the stored row,
/// so each test empties it before checking what was actually written.
@MainActor @Suite final class ArticleUpdateTests {

	private let database: ArticlesDatabase
	private let feedID = "feed1"
	private let uniqueID = "1"

	init() {
		self.database = ArticlesDatabase(databaseFilePath: ":memory:", accountID: "test", retentionStyle: .feedBased)
	}

	@Test func identicalUpdateReportsNoChanges() async {
		let item = parsedItem(title: "Title", markdown: nil, attachments: nil, thumbnailURL: nil)
		let firstChanges = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)
		#expect(firstChanges.new?.count == 1)

		database.emptyCaches()
		let secondChanges = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)
		#expect(secondChanges.new == nil)
		#expect(secondChanges.updated == nil)
	}

	@Test func markdownChangePersists() async {
		let original = parsedItem(title: "Title", markdown: "one", attachments: nil, thumbnailURL: nil)
		_ = await database.updateAsync(parsedItems: [original], feedID: feedID, deleteOlder: false)

		let edited = parsedItem(title: "Title", markdown: "two", attachments: nil, thumbnailURL: nil)
		let changes = await database.updateAsync(parsedItems: [edited], feedID: feedID, deleteOlder: false)
		#expect(changes.updated?.count == 1)

		database.emptyCaches()
		let fetched = await database.fetchArticlesAsync(feedID: feedID).first
		#expect(fetched?.markdown == "two")
	}

	@Test func clearedFieldStopsReportingAsUpdated() async {
		let withTitle = parsedItem(title: "Title", markdown: nil, attachments: nil, thumbnailURL: nil)
		_ = await database.updateAsync(parsedItems: [withTitle], feedID: feedID, deleteOlder: false)

		let withoutTitle = parsedItem(title: nil, markdown: nil, attachments: nil, thumbnailURL: nil)
		let clearingChanges = await database.updateAsync(parsedItems: [withoutTitle], feedID: feedID, deleteOlder: false)
		#expect(clearingChanges.updated?.count == 1)

		database.emptyCaches()
		let fetched = await database.fetchArticlesAsync(feedID: feedID).first
		#expect(fetched?.title == nil)

		database.emptyCaches()
		let repeatChanges = await database.updateAsync(parsedItems: [withoutTitle], feedID: feedID, deleteOlder: false)
		#expect(repeatChanges.updated == nil)
	}

	@Test func equalityComparesMarkdown() {
		let one = article(markdown: "one")
		let two = article(markdown: "two")
		#expect(one != two)
		#expect(one == article(markdown: "one"))
	}

	@Test func attachmentsPersist() async throws {
		let item = parsedItem(title: "Title", markdown: nil, attachments: [try episodeAttachment(durationInSeconds: 3600)], thumbnailURL: nil)
		_ = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)

		database.emptyCaches()
		let fetched = await database.fetchArticlesAsync(feedID: feedID).first
		let attachment = try #require(fetched?.attachments?.first)
		#expect(fetched?.attachments?.count == 1)
		#expect(attachment.url == "https://example.com/episode.mp3")
		#expect(attachment.mimeType == "audio/mpeg")
		#expect(attachment.sizeInBytes == 12345678)
		#expect(attachment.durationInSeconds == 3600)
		#expect(attachment.medium == .audio)
	}

	@Test func attachmentOnlyChangeIsUpdate() async throws {
		let original = parsedItem(title: "Title", markdown: nil, attachments: [try episodeAttachment(durationInSeconds: nil)], thumbnailURL: nil)
		_ = await database.updateAsync(parsedItems: [original], feedID: feedID, deleteOlder: false)

		database.emptyCaches()
		let edited = parsedItem(title: "Title", markdown: nil, attachments: [try episodeAttachment(durationInSeconds: 3600)], thumbnailURL: nil)
		let changes = await database.updateAsync(parsedItems: [edited], feedID: feedID, deleteOlder: false)
		#expect(changes.updated?.count == 1)

		database.emptyCaches()
		let fetched = await database.fetchArticlesAsync(feedID: feedID).first
		#expect(fetched?.attachments?.first?.durationInSeconds == 3600)
	}

	@Test func clearedAttachmentsStopReportingAsUpdated() async throws {
		let withAttachments = parsedItem(title: "Title", markdown: nil, attachments: [try episodeAttachment(durationInSeconds: 3600)], thumbnailURL: nil)
		_ = await database.updateAsync(parsedItems: [withAttachments], feedID: feedID, deleteOlder: false)

		database.emptyCaches()
		let withoutAttachments = parsedItem(title: "Title", markdown: nil, attachments: nil, thumbnailURL: nil)
		let clearingChanges = await database.updateAsync(parsedItems: [withoutAttachments], feedID: feedID, deleteOlder: false)
		#expect(clearingChanges.updated?.count == 1)

		database.emptyCaches()
		let fetched = await database.fetchArticlesAsync(feedID: feedID).first
		#expect(fetched?.attachments == nil)

		database.emptyCaches()
		let repeatChanges = await database.updateAsync(parsedItems: [withoutAttachments], feedID: feedID, deleteOlder: false)
		#expect(repeatChanges.updated == nil)
	}

	@Test func thumbnailChangePersists() async {
		let original = parsedItem(title: "Title", markdown: nil, attachments: nil, thumbnailURL: "https://example.com/small.jpg")
		_ = await database.updateAsync(parsedItems: [original], feedID: feedID, deleteOlder: false)

		database.emptyCaches()
		let edited = parsedItem(title: "Title", markdown: nil, attachments: nil, thumbnailURL: "https://example.com/small-2.jpg")
		let changes = await database.updateAsync(parsedItems: [edited], feedID: feedID, deleteOlder: false)
		#expect(changes.updated?.count == 1)

		database.emptyCaches()
		let fetched = await database.fetchArticlesAsync(feedID: feedID).first
		#expect(fetched?.rawThumbnailLink == "https://example.com/small-2.jpg")
	}
}

// MARK: - Helpers

private extension ArticleUpdateTests {

	func parsedItem(title: String?, markdown: String?, attachments: [ParsedAttachment]?, thumbnailURL: String?) -> ParsedItem {
		ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: feedID, url: "https://example.com/\(uniqueID)", externalURL: nil, title: title, language: nil, contentHTML: "<p>Test</p>", contentText: nil, markdown: markdown, summary: nil, imageURL: nil, thumbnailURL: thumbnailURL, bannerImageURL: nil, datePublished: Date(timeIntervalSince1970: 0), dateModified: nil, authors: nil, tags: nil, attachments: attachments)
	}

	func article(markdown: String?) -> Article {
		let status = ArticleStatus(articleID: "article1", read: false, starred: false, dateArrived: Date(timeIntervalSince1970: 0))
		return Article(accountID: "test", articleID: "article1", feedID: feedID, uniqueID: uniqueID, title: "Title", contentHTML: "<p>Test</p>", contentText: nil, markdown: markdown, url: nil, externalURL: nil, summary: nil, imageURL: nil, thumbnailURL: nil, datePublished: nil, dateModified: nil, authors: nil, attachments: nil, status: status)
	}

	func episodeAttachment(durationInSeconds: Int?) throws -> ParsedAttachment {
		try #require(ParsedAttachment(url: "https://example.com/episode.mp3", mimeType: "audio/mpeg", title: nil, sizeInBytes: 12345678, durationInSeconds: durationInSeconds, width: nil, height: nil, medium: .audio))
	}
}
