//
//  StatusDeletionTests.swift
//  ArticlesDatabase
//
//  Created by Brent Simmons on 11/24/26.
//

import Foundation
import Testing
import Articles
import RSParser
import ArticlesDatabase

@MainActor @Suite final class StatusDeletionTests {

	private let database: ArticlesDatabase
	private let feedID = "feed1"
	private let articleID = "5001"

	init() {
		self.database = ArticlesDatabase(databaseFilePath: ":memory:", accountID: "test", retentionStyle: .syncSystem)
	}

	/// The sync service reports the article deleted, then sends it again later. It must come back unread.
	@Test func articleSavedAfterItsStatusIsDeletedGetsNewStatus() async {
		_ = await database.updateAsync(feedIDsAndItems: [feedID: [parsedItem()]], defaultRead: false)
		#expect(await database.fetchUnreadArticleIDsAsync() == [articleID])

		await database.deleteAsync(articleIDs: [articleID])
		await database.deleteStatusesAsync(articleIDs: [articleID])
		#expect(await database.fetchUnreadArticleIDsAsync().isEmpty)

		_ = await database.updateAsync(feedIDsAndItems: [feedID: [parsedItem()]], defaultRead: false)
		#expect(await database.fetchUnreadArticleIDsAsync() == [articleID])
	}
}

// MARK: - Helpers

private extension StatusDeletionTests {

	func parsedItem() -> ParsedItem {
		ParsedItem(syncServiceID: articleID, uniqueID: articleID, feedURL: feedID, url: "https://example.com/\(articleID)", externalURL: nil, title: "Article \(articleID)", language: nil, contentHTML: "<p>Test</p>", contentText: nil, markdown: nil, summary: nil, imageURL: nil, thumbnailURL: nil, bannerImageURL: nil, datePublished: Date(), dateModified: nil, authors: nil, tags: nil, attachments: nil)
	}
}
