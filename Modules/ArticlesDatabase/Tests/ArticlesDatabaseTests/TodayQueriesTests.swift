//
//  TodayQueriesTests.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 9/18/26.
//

import Foundation
import Testing
import Articles
import RSParser
import ArticlesDatabase

/// The Today smart feed selects articles published in the last 24 hours, falling back
/// to dateArrived when datePublished is nil. These tests pin that behavior for the
/// unread count, the total count, and the article fetch.
@MainActor @Suite final class TodayQueriesTests {

	private let database: ArticlesDatabase
	private let feedA = "feedA"
	private let feedB = "feedB"
	private var articleIDsByUniqueID = [String: String]()

	private static let oneHourAgo = Date(timeIntervalSinceNow: -(60 * 60))
	private static let twentyFiveHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 25))

	init() {
		self.database = ArticlesDatabase(databaseFilePath: ":memory:", accountID: "test", retentionStyle: .feedBased)
	}

	@Test func todayUnreadCountAcrossFeeds() async {
		await seedArticles()
		#expect(await database.fetchUnreadCountForTodayAsync(feedIDs: [feedA, feedB]) == 2)
	}

	@Test func todayUnreadCountForOneFeed() async {
		await seedArticles()
		#expect(await database.fetchUnreadCountForTodayAsync(feedIDs: [feedA]) == 1)
		#expect(await database.fetchUnreadCountForTodayAsync(feedIDs: [feedB]) == 1)
	}

	@Test func todayTotalCountAcrossFeeds() async {
		await seedArticles()
		#expect(await database.fetchTodayArticlesCountAsync(feedIDs: [feedA, feedB]) == 4)
	}

	@Test func todayTotalCountForOneFeed() async {
		await seedArticles()
		#expect(await database.fetchTodayArticlesCountAsync(feedIDs: [feedA]) == 2)
		#expect(await database.fetchTodayArticlesCountAsync(feedIDs: [feedB]) == 2)
	}

	@Test func todayArticlesAcrossFeeds() async {
		await seedArticles()
		let articles = await database.fetchTodayArticlesAsync(feedIDs: [feedA, feedB])
		let expected = articleIDs(forUniqueIDs: ["a-recent", "a-nil", "b-recent", "b-nil"])
		#expect(Set(articles.map { $0.articleID }) == expected)
	}

	@Test func todayArticlesForOneFeed() async {
		await seedArticles()
		let articles = await database.fetchTodayArticlesAsync(feedIDs: [feedA])
		let expected = articleIDs(forUniqueIDs: ["a-recent", "a-nil"])
		#expect(Set(articles.map { $0.articleID }) == expected)
	}

	@Test func todayArticlesWithLimit() async {
		await seedArticles()
		let articles = await database.fetchTodayArticlesAsync(feedIDs: [feedA, feedB], limit: 3)
		#expect(articles.count == 3)
		let inWindow = articleIDs(forUniqueIDs: ["a-recent", "a-nil", "b-recent", "b-nil"])
		#expect(Set(articles.map { $0.articleID }).isSubset(of: inWindow))
	}

	@Test func emptyFeedIDsReturnNothing() async {
		await seedArticles()
		#expect(await database.fetchUnreadCountForTodayAsync(feedIDs: []) == 0)
		#expect(await database.fetchTodayArticlesCountAsync(feedIDs: []) == 0)
		#expect(await database.fetchTodayArticlesAsync(feedIDs: []).isEmpty)
	}
}

// MARK: - Helpers

private extension TodayQueriesTests {

	// Per feed: one article published an hour ago, one 25 hours ago, and one with no
	// datePublished (dateArrived is insert time, so it falls inside the window).
	// Then a-recent and b-nil are marked read.
	func seedArticles() async {
		await seedFeed(feedA, prefix: "a")
		await seedFeed(feedB, prefix: "b")
		let readArticleIDs = articleIDs(forUniqueIDs: ["a-recent", "b-nil"])
		let changed = await database.markAsync(articleIDs: readArticleIDs, statusKey: .read, flag: true)
		#expect(changed == readArticleIDs)
	}

	func seedFeed(_ feedID: String, prefix: String) async {
		let items: Set<ParsedItem> = [
			parsedItem(uniqueID: "\(prefix)-recent", feedID: feedID, datePublished: Self.oneHourAgo),
			parsedItem(uniqueID: "\(prefix)-old", feedID: feedID, datePublished: Self.twentyFiveHoursAgo),
			parsedItem(uniqueID: "\(prefix)-nil", feedID: feedID, datePublished: nil)
		]
		let changes = await database.updateAsync(parsedItems: items, feedID: feedID, deleteOlder: false)
		let newArticles = changes.new ?? Set<Article>()
		#expect(newArticles.count == items.count)
		for article in newArticles {
			articleIDsByUniqueID[article.uniqueID] = article.articleID
		}
	}

	func articleIDs(forUniqueIDs uniqueIDs: [String]) -> Set<String> {
		Set(uniqueIDs.compactMap { articleIDsByUniqueID[$0] })
	}

	func parsedItem(uniqueID: String, feedID: String, datePublished: Date?) -> ParsedItem {
		ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: feedID, url: "https://example.com/\(uniqueID)", externalURL: nil, title: "Article \(uniqueID)", language: nil, contentHTML: "<p>Test</p>", contentText: nil, markdown: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: datePublished, dateModified: nil, authors: nil, tags: nil, attachments: nil)
	}
}
