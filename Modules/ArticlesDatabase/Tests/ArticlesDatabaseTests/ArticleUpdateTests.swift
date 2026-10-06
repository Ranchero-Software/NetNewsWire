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
		let item = parsedItem(title: "Title", markdown: nil)
		let firstChanges = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)
		#expect(firstChanges.new?.count == 1)

		database.emptyCaches()
		let secondChanges = await database.updateAsync(parsedItems: [item], feedID: feedID, deleteOlder: false)
		#expect(secondChanges.new == nil)
		#expect(secondChanges.updated == nil)
	}

	@Test func markdownChangePersists() async {
		let original = parsedItem(title: "Title", markdown: "one")
		_ = await database.updateAsync(parsedItems: [original], feedID: feedID, deleteOlder: false)

		let edited = parsedItem(title: "Title", markdown: "two")
		let changes = await database.updateAsync(parsedItems: [edited], feedID: feedID, deleteOlder: false)
		#expect(changes.updated?.count == 1)

		database.emptyCaches()
		let fetched = await database.fetchArticlesAsync(feedID: feedID).first
		#expect(fetched?.markdown == "two")
	}

	@Test func clearedFieldStopsReportingAsUpdated() async {
		let withTitle = parsedItem(title: "Title", markdown: nil)
		_ = await database.updateAsync(parsedItems: [withTitle], feedID: feedID, deleteOlder: false)

		let withoutTitle = parsedItem(title: nil, markdown: nil)
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
}

// MARK: - Helpers

private extension ArticleUpdateTests {

	func parsedItem(title: String?, markdown: String?) -> ParsedItem {
		ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: feedID, url: "https://example.com/\(uniqueID)", externalURL: nil, title: title, language: nil, contentHTML: "<p>Test</p>", contentText: nil, markdown: markdown, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: Date(timeIntervalSince1970: 0), dateModified: nil, authors: nil, tags: nil, attachments: nil)
	}

	func article(markdown: String?) -> Article {
		let status = ArticleStatus(articleID: "article1", read: false, starred: false, dateArrived: Date(timeIntervalSince1970: 0))
		return Article(accountID: "test", articleID: "article1", feedID: feedID, uniqueID: uniqueID, title: "Title", contentHTML: "<p>Test</p>", contentText: nil, markdown: markdown, url: nil, externalURL: nil, summary: nil, imageURL: nil, datePublished: nil, dateModified: nil, authors: nil, status: status)
	}
}
