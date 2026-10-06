//
//  StatusDivergenceTests.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 8/11/26.
//

import Foundation
import Testing
import Articles
import RSParser
import ArticlesDatabase

/// A database status row can miss a write (the write goes through memory first),
/// leaving the row unread while the in-memory status says read — a phantom
/// unread count. These tests reproduce that state and verify it self-heals.
@MainActor @Suite final class StatusDivergenceTests {

	private let database: ArticlesDatabase
	private let feedID = "feed1"

	init() {
		self.database = ArticlesDatabase(databaseFilePath: ":memory:", accountID: "test", retentionStyle: .feedBased)
	}

	@Test func statusRepairFixesStaleReadStatusRows() async {
		let articles = await seedTwoUnreadArticles()
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 2)

		// Reproduce a lost write: read in memory, unread in the database.
		for article in articles {
			article.status.setBoolStatus(true, forKey: .read)
		}
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 2)

		// The count query is enqueued behind the repair on the serial database
		// queue, so it sees the repaired rows.
		database.repairStatuses()
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 0)
	}

	@Test func markRepairsStaleReadStatusRows() async {
		let articles = await seedTwoUnreadArticles()
		for article in articles {
			article.status.setBoolStatus(true, forKey: .read)
		}
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 2)

		// Marking repairs the rows even though memory already matches,
		// and reports no changed articles.
		let articleIDs = Set(articles.map { $0.articleID })
		let changedArticleIDs = await database.markAsync(articleIDs: articleIDs, statusKey: .read, flag: true)
		#expect(changedArticleIDs.isEmpty)
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 0)
	}

	@Test func statusRepairFixesStaleStarredStatusRows() async {
		let articles = await seedTwoUnreadArticles()
		for article in articles {
			article.status.setBoolStatus(true, forKey: .starred)
		}
		#expect(await database.fetchStarredArticleIDsAsync().isEmpty)

		database.repairStatuses()

		let articleIDs = Set(articles.map { $0.articleID })
		#expect(await database.fetchStarredArticleIDsAsync() == articleIDs)
	}

	@Test func statusRepairIsHarmlessWhenNothingIsStale() async {
		_ = await seedTwoUnreadArticles()

		database.repairStatuses()

		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 2)
		#expect(await database.fetchStarredArticleIDsAsync().isEmpty)
	}

	@Test func statusRepairFixesStaleUnreadStatusRows() async {
		let articles = await seedTwoUnreadArticles()
		let articleIDs = Set(articles.map { $0.articleID })
		_ = await database.markAsync(articleIDs: articleIDs, statusKey: .read, flag: true)
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 0)

		// Reproduce a lost write in the other direction: unread in memory, read in the database.
		for article in articles {
			article.status.setBoolStatus(false, forKey: .read)
		}
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 0)

		database.repairStatuses()
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 2)
	}

	@Test func statusRepairFixesMoreStatusesThanOneChunk() async {
		// More than the repair pass's 500-status chunk, so the second chunk is exercised.
		let articleCount = 501
		let articles = await seedUnreadArticles(count: articleCount)
		for article in articles {
			article.status.setBoolStatus(true, forKey: .read)
		}
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == articleCount)

		database.repairStatuses()
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 0)
	}

	@Test func normalMarksStillReportChanges() async {
		let articles = await seedTwoUnreadArticles()
		let articleIDs = Set(articles.map { $0.articleID })

		let markedRead = await database.markAsync(articleIDs: articleIDs, statusKey: .read, flag: true)
		#expect(markedRead == articleIDs)
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 0)

		let markedUnread = await database.markAsync(articleIDs: articleIDs, statusKey: .read, flag: false)
		#expect(markedUnread == articleIDs)
		#expect(await database.fetchUnreadCountAsync(feedID: feedID) == 2)
	}
}

// MARK: - Helpers

private extension StatusDivergenceTests {

	func seedTwoUnreadArticles() async -> [Article] {
		await seedUnreadArticles(count: 2)
	}

	func seedUnreadArticles(count: Int) async -> [Article] {
		let items = Set((1...count).map { parsedItem(uniqueID: String($0)) })
		let changes = await database.updateAsync(parsedItems: items, feedID: feedID, deleteOlder: false)
		let newArticles = changes.new ?? Set<Article>()
		#expect(newArticles.count == count)
		return Array(newArticles)
	}

	func parsedItem(uniqueID: String) -> ParsedItem {
		ParsedItem(syncServiceID: nil, uniqueID: uniqueID, feedURL: feedID, url: "https://example.com/\(uniqueID)", externalURL: nil, title: "Article \(uniqueID)", language: nil, contentHTML: "<p>Test</p>", contentText: nil, markdown: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: Date(), dateModified: nil, authors: nil, tags: nil, attachments: nil)
	}
}
