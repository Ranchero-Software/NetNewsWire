//
//  ArticleSorterTests.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Articles
import Foundation
import XCTest

@testable import NetNewsWire

@MainActor final class ArticleSorterTests: XCTestCase {

	// MARK: sortByDate ascending tests

	func testSortByDateAscending() {
		let now = Date()

		let article1 = makeArticle(date: now.addingTimeInterval(-60.0), articleID: "1", feedID: "4")
		let article2 = makeArticle(date: now.addingTimeInterval(60.0), articleID: "2", feedID: "6")
		let article3 = makeArticle(date: now.addingTimeInterval(120.0), articleID: "3", feedID: "6")
		let article4 = makeArticle(date: now.addingTimeInterval(-120.0), articleID: "4", feedID: "5")

		let articles = [article1, article2, article3, article4]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedAscending, groupByFeed: false)

		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article3)
	}

	func testSortByDateAscendingWithSameDate() {
		let now = Date()

		// Articles with the same date should end up being sorted by their article ID
		let article1 = makeArticle(date: now, articleID: "1", feedID: "1")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "2")
		let article3 = makeArticle(date: now, articleID: "3", feedID: "3")
		let article4 = makeArticle(date: Date(timeInterval: -60.0, since: now), articleID: "4", feedID: "4")
		let article5 = makeArticle(date: Date(timeInterval: -120.0, since: now), articleID: "5", feedID: "5")

		let articles = [article1, article2, article3, article4, article5]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedAscending, groupByFeed: false)

		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article5)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article3)
	}

	func testSortByDateAscendingWithGroupByFeed() {
		let now = Date()

		let article1 = makeArticle(date: Date(timeInterval: -100.0, since: now), articleID: "1", feedID: "1")
		let article2 = makeArticle(date: now, articleID: "1", feedID: "2")
		let article3 = makeArticle(date: Date(timeInterval: -10.0, since: now), articleID: "2", feedID: "2")
		let article4 = makeArticle(date: Date(timeInterval: -1000.0, since: now), articleID: "1", feedID: "3")
		let article5 = makeArticle(date: Date(timeInterval: -10.0, since: now), articleID: "2", feedID: "3")
		let article6 = makeArticle(date: Date(timeInterval: 10.0, since: now), articleID: "3", feedID: "2")
		let article7 = makeArticle(date: now, articleID: "2", feedID: "1")
		let article8 = makeArticle(date: now, articleID: "1", feedID: "0")
		let article9 = makeArticle(date: now, articleID: "2", feedID: "0")

		let articles = [article1, article2, article3, article4, article5, article6, article7, article8, article9]
		let names: [String: String] = [
			"1": "Phil's Feed",
			"2": "Jenny's Feed",
			"3": "Gordy's Blog",
			"0": "Zippy's Feed"
		]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedAscending, groupByFeed: true) {
			names[$0.feedID] ?? ""
		}

		XCTAssertEqual(sortedArticles.count, 9)

		// Gordy's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(0), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article5)
		// Jenny's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(2), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article6)
		// Phil's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(5), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(6), article7)
		// Zippy's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(7), article8)
		XCTAssertEqual(sortedArticles.articleAtRow(8), article9)
	}

	// MARK: sortByDate descending tests

	func testSortByDateDescending() {
		let now = Date()

		let article1 = makeArticle(date: now.addingTimeInterval(-60.0), articleID: "1", feedID: "4")
		let article2 = makeArticle(date: now.addingTimeInterval(60.0), articleID: "2", feedID: "6")
		let article3 = makeArticle(date: now.addingTimeInterval(120.0), articleID: "3", feedID: "6")
		let article4 = makeArticle(date: now.addingTimeInterval(-120.0), articleID: "4", feedID: "5")

		let articles = [article1, article2, article3, article4]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedDescending, groupByFeed: false)

		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article4)
	}

	func testSortByDateDescendingWithSameDate() {
		let now = Date()

		// Articles with the same date should end up being sorted by their article ID
		let article1 = makeArticle(date: now, articleID: "1", feedID: "1")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "2")
		let article3 = makeArticle(date: now, articleID: "3", feedID: "3")
		let article4 = makeArticle(date: Date(timeInterval: -60.0, since: now), articleID: "4", feedID: "4")
		let article5 = makeArticle(date: Date(timeInterval: -120.0, since: now), articleID: "5", feedID: "5")

		let articles = [article1, article2, article3, article4, article5]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedDescending, groupByFeed: false)

		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article5)
	}

	func testSortByDateDescendingWithGroupByFeed() {
		let now = Date()

		let article1 = makeArticle(date: Date(timeInterval: -100.0, since: now), articleID: "1", feedID: "1")
		let article2 = makeArticle(date: now, articleID: "1", feedID: "2")
		let article3 = makeArticle(date: Date(timeInterval: -10.0, since: now), articleID: "2", feedID: "2")
		let article4 = makeArticle(date: Date(timeInterval: -1000.0, since: now), articleID: "1", feedID: "3")
		let article5 = makeArticle(date: Date(timeInterval: -10.0, since: now), articleID: "2", feedID: "3")
		let article6 = makeArticle(date: Date(timeInterval: 10.0, since: now), articleID: "3", feedID: "2")
		let article7 = makeArticle(date: now, articleID: "2", feedID: "1")
		let article8 = makeArticle(date: now, articleID: "1", feedID: "0")
		let article9 = makeArticle(date: now, articleID: "2", feedID: "0")

		let articles = [article1, article2, article3, article4, article5, article6, article7, article8, article9]
		let names: [String: String] = [
			"1": "Phil's Feed",
			"2": "Jenny's Feed",
			"3": "Gordy's Blog",
			"0": "Zippy's Feed"
		]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedDescending, groupByFeed: true) {
			names[$0.feedID] ?? ""
		}

		XCTAssertEqual(sortedArticles.count, 9)

		// Gordy's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(0), article5)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article4)
		// Jenny's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(2), article6)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article3)
		// Phil's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(5), article7)
		XCTAssertEqual(sortedArticles.articleAtRow(6), article1)
		// Zippy's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(7), article8)
		XCTAssertEqual(sortedArticles.articleAtRow(8), article9)
	}

	// MARK: Additional group by feed tests

	func testGroupByFeedWithCaseInsensitiveFeedNames() {
		let now = Date()

		let article1 = makeArticle(date: now, articleID: "1", feedID: "1")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "1")
		let article3 = makeArticle(date: now, articleID: "3", feedID: "2")
		let article4 = makeArticle(date: now, articleID: "4", feedID: "1")
		let article5 = makeArticle(date: now, articleID: "5", feedID: "2")

		let articles = [article1, article2, article3, article4, article5]
		let names: [String: String] = [
			"1": "phil's feed",
			"2": "APPLE's feed"
		]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedAscending, groupByFeed: true) {
			names[$0.feedID] ?? ""
		}

		XCTAssertEqual(sortedArticles.count, articles.count)

		// Apple's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(0), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article5)
		// Phil's feed articles
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article4)
	}

	func testGroupByFeedWithSameFeedNames() {
		let now = Date()

		// Articles with the same feed name should be sorted by feed ID
		let article1 = makeArticle(date: now, articleID: "1", feedID: "2")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "2")
		let article3 = makeArticle(date: now, articleID: "3", feedID: "1")
		let article4 = makeArticle(date: now, articleID: "4", feedID: "2")
		let article5 = makeArticle(date: now, articleID: "5", feedID: "1")

		let articles = [article1, article2, article3, article4, article5]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedAscending, groupByFeed: true) { _ in
			"Phil's Feed"
		}

		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article5)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article4)
	}

	// MARK: sorted(by:) tests

	func testSortedByParametersDateMatchesSortedByDate() {
		let now = Date()

		let article1 = makeArticle(date: now.addingTimeInterval(-60.0), articleID: "1", feedID: "4")
		let article2 = makeArticle(date: now.addingTimeInterval(60.0), articleID: "2", feedID: "6")
		let article3 = makeArticle(date: now.addingTimeInterval(120.0), articleID: "3", feedID: "6")

		let articles = [article1, article2, article3]
		let parameters = ArticleSortParameters(key: .date, direction: .orderedDescending, groupByFeed: false)
		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters)

		XCTAssertEqual(sortedArticles, ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedDescending, groupByFeed: false))
		XCTAssertEqual(sortedArticles.articleAtRow(0), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
	}

	func testSortedByTitleAscendingIgnoresCaseAndBreaksTiesByNewestDate() {
		let now = Date()

		let article1 = makeArticle(date: now, articleID: "1", feedID: "1", title: "banana")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "1", title: "Apple")
		let article3 = makeArticle(date: now.addingTimeInterval(-60.0), articleID: "3", feedID: "1", title: "apple")
		let article4 = makeArticle(date: now, articleID: "4", feedID: "1", title: nil)

		let articles = [article1, article2, article3, article4]
		let parameters = ArticleSortParameters(key: .title, direction: .orderedAscending, groupByFeed: false)
		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters)

		XCTAssertEqual(sortedArticles.articleAtRow(0), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article1)
	}

	func testSortedByTitleDescending() {
		let now = Date()

		let article1 = makeArticle(date: now, articleID: "1", feedID: "1", title: "banana")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "1", title: "Apple")
		let article3 = makeArticle(date: now, articleID: "3", feedID: "1", title: "cherry")

		let articles = [article1, article2, article3]
		let parameters = ArticleSortParameters(key: .title, direction: .orderedDescending, groupByFeed: false)
		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters)

		XCTAssertEqual(sortedArticles.articleAtRow(0), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article2)
	}

	func testSortedByFeedAscendingMatchesGroupByFeed() {
		let now = Date()

		let article1 = makeArticle(date: now.addingTimeInterval(-100.0), articleID: "1", feedID: "1")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "2")
		let article3 = makeArticle(date: now.addingTimeInterval(-10.0), articleID: "3", feedID: "2")
		let article4 = makeArticle(date: now, articleID: "4", feedID: "1")

		let articles = [article1, article2, article3, article4]
		let names: [String: String] = ["1": "Phil's Feed", "2": "Jenny's Feed"]
		let parameters = ArticleSortParameters(key: .feed, direction: .orderedAscending, groupByFeed: false)
		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters) {
			names[$0.feedID] ?? ""
		}

		// Jenny's feed, newest first, then Phil's feed.
		XCTAssertEqual(sortedArticles.articleAtRow(0), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article1)
	}

	func testSortedByFeedDescendingReversesFeedOrderOnly() {
		let now = Date()

		let article1 = makeArticle(date: now.addingTimeInterval(-100.0), articleID: "1", feedID: "1")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "2")
		let article3 = makeArticle(date: now.addingTimeInterval(-10.0), articleID: "3", feedID: "2")
		let article4 = makeArticle(date: now, articleID: "4", feedID: "1")

		let articles = [article1, article2, article3, article4]
		let names: [String: String] = ["1": "Phil's Feed", "2": "Jenny's Feed"]
		let parameters = ArticleSortParameters(key: .feed, direction: .orderedDescending, groupByFeed: false)
		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters) {
			names[$0.feedID] ?? ""
		}

		// Phil's feed, newest first, then Jenny's feed.
		XCTAssertEqual(sortedArticles.articleAtRow(0), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article3)
	}

	func testSortedByUnreadDescendingPutsUnreadOnTop() {
		let now = Date()

		let article1 = makeArticle(date: now, articleID: "1", feedID: "1", read: true)
		let article2 = makeArticle(date: now.addingTimeInterval(-60.0), articleID: "2", feedID: "1", read: false)
		let article3 = makeArticle(date: now.addingTimeInterval(60.0), articleID: "3", feedID: "1", read: true)
		let article4 = makeArticle(date: now, articleID: "4", feedID: "1", read: false)

		let articles = [article1, article2, article3, article4]
		let parameters = ArticleSortParameters(key: .unread, direction: .orderedDescending, groupByFeed: false)
		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters)

		XCTAssertEqual(sortedArticles.articleAtRow(0), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article1)
	}

	func testSortedByStarredAscendingPutsStarredOnBottom() {
		let now = Date()

		let article1 = makeArticle(date: now, articleID: "1", feedID: "1", starred: true)
		let article2 = makeArticle(date: now.addingTimeInterval(-60.0), articleID: "2", feedID: "1", starred: false)
		let article3 = makeArticle(date: now.addingTimeInterval(60.0), articleID: "3", feedID: "1", starred: true)

		let articles = [article1, article2, article3]
		let parameters = ArticleSortParameters(key: .starred, direction: .orderedAscending, groupByFeed: false)
		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters)

		XCTAssertEqual(sortedArticles.articleAtRow(0), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
	}

	func testGroupByFeedIsIgnoredForNonDateKeys() {
		let now = Date()

		let article1 = makeArticle(date: now, articleID: "1", feedID: "1", title: "b")
		let article2 = makeArticle(date: now, articleID: "2", feedID: "2", title: "a")

		let articles = [article1, article2]
		let parameters = ArticleSortParameters(key: .title, direction: .orderedAscending, groupByFeed: true)
		XCTAssertFalse(parameters.effectiveGroupByFeed)

		let sortedArticles = ArticleSorter.sorted(articles: articles, parameters: parameters) { _ in "Same Name" }
		XCTAssertEqual(sortedArticles.articleAtRow(0), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article1)
	}
}

// MARK: - Helpers

@MainActor private func makeArticle(date: Date, articleID: String, feedID: String, title: String? = nil, read: Bool = false, starred: Bool = false) -> Article {
	Article(accountID: "test-account",
			articleID: articleID,
			feedID: feedID,
			uniqueID: articleID,
			title: title,
			contentHTML: nil,
			contentText: nil,
			markdown: nil,
			url: nil,
			externalURL: nil,
			summary: nil,
			imageURL: nil,
			datePublished: date,
			dateModified: nil,
			authors: nil,
			status: ArticleStatus(articleID: articleID, read: read, starred: starred, dateArrived: date))
}
