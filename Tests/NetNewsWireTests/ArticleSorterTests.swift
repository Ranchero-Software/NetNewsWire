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

class ArticleSorterTests: XCTestCase {
	
	// MARK: sortByDate ascending tests
	
	func testSortByDateAscending() {
		let now = Date()
		
		let article1 = TestArticle(sortableName: "Susie's Feed", sortableDate: now.addingTimeInterval(-60.0), sortableArticleID: "1", sortableFeedID: "4")
		let article2 = TestArticle(sortableName: "Phil's Feed", sortableDate: now.addingTimeInterval(60.0), sortableArticleID: "2", sortableFeedID: "6")
		let article3 = TestArticle(sortableName: "Phil's Feed", sortableDate: now.addingTimeInterval(120.0), sortableArticleID: "3", sortableFeedID: "6")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: now.addingTimeInterval(-120.0), sortableArticleID: "4", sortableFeedID: "5")
		
		let articles = [article1, article2, article3, article4]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedAscending,
														groupByFeed: false)
		
		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article3)
	}
	
	func testSortByDateAscendingWithSameDate() {
		let now = Date()
		
		// Articles with the same date should end up being sorted by their article ID
		let article1 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "1")
		let article2 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "2")
		let article3 = TestArticle(sortableName: "Sally's Feed", sortableDate: now, sortableArticleID: "3", sortableFeedID: "3")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableArticleID: "4", sortableFeedID: "4")
		let article5 = TestArticle(sortableName: "Paul's Feed", sortableDate: Date(timeInterval: -120.0, since: now), sortableArticleID: "5", sortableFeedID: "5")
		
		let articles = [article1, article2, article3, article4, article5]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedAscending,
														groupByFeed: false)
		
		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article5)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article3)
	}
	
	func testSortByDateAscendingWithGroupByFeed() {
		let now = Date()

		let article1 = TestArticle(sortableName: "Phil's Feed", sortableDate: Date(timeInterval: -100.0, since: now), sortableArticleID: "1", sortableFeedID: "1")
		let article2 = TestArticle(sortableName: "Jenny's Feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "2")
		let article3 = TestArticle(sortableName: "Jenny's Feed", sortableDate: Date(timeInterval: -10.0, since: now), sortableArticleID: "2", sortableFeedID: "2")
		let article4 = TestArticle(sortableName: "Gordy's Blog", sortableDate: Date(timeInterval: -1000.0, since: now), sortableArticleID: "1", sortableFeedID: "3")
		let article5 = TestArticle(sortableName: "Gordy's Blog", sortableDate: Date(timeInterval: -10.0, since: now), sortableArticleID: "2", sortableFeedID: "3")
		let article6 = TestArticle(sortableName: "Jenny's Feed", sortableDate: Date(timeInterval: 10.0, since: now), sortableArticleID: "3", sortableFeedID: "2")
		let article7 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "1")
		let article8 = TestArticle(sortableName: "Zippy's Feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "0")
		let article9 = TestArticle(sortableName: "Zippy's Feed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "0")
		
		let articles = [article1, article2, article3, article4, article5, article6, article7, article8, article9]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedAscending, groupByFeed: true)
		
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
		
		let article1 = TestArticle(sortableName: "Susie's Feed", sortableDate: now.addingTimeInterval(-60.0), sortableArticleID: "1", sortableFeedID: "4")
		let article2 = TestArticle(sortableName: "Phil's Feed", sortableDate: now.addingTimeInterval(60.0), sortableArticleID: "2", sortableFeedID: "6")
		let article3 = TestArticle(sortableName: "Phil's Feed", sortableDate: now.addingTimeInterval(120.0), sortableArticleID: "3", sortableFeedID: "6")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: now.addingTimeInterval(-120.0), sortableArticleID: "4", sortableFeedID: "5")
		
		let articles = [article1, article2, article3, article4]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedDescending,
														groupByFeed: false)
		
		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article4)
	}
	
	func testSortByDateDescendingWithSameDate() {
		let now = Date()
		
		// Articles with the same date should end up being sorted by their article ID
		let article1 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "1")
		let article2 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "2")
		let article3 = TestArticle(sortableName: "Sally's Feed", sortableDate: now, sortableArticleID: "3", sortableFeedID: "3")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableArticleID: "4", sortableFeedID: "4")
		let article5 = TestArticle(sortableName: "Paul's Feed", sortableDate: Date(timeInterval: -120.0, since: now), sortableArticleID: "5", sortableFeedID: "5")
		
		let articles = [article1, article2, article3, article4, article5]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedDescending,
														groupByFeed: false)
		
		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article4)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article5)
	}
	
	func testSortByDateDescendingWithGroupByFeed() {
		let now = Date()

		let article1 = TestArticle(sortableName: "Phil's Feed", sortableDate: Date(timeInterval: -100.0, since: now), sortableArticleID: "1", sortableFeedID: "1")
		let article2 = TestArticle(sortableName: "Jenny's Feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "2")
		let article3 = TestArticle(sortableName: "Jenny's Feed", sortableDate: Date(timeInterval: -10.0, since: now), sortableArticleID: "2", sortableFeedID: "2")
		let article4 = TestArticle(sortableName: "Gordy's Blog", sortableDate: Date(timeInterval: -1000.0, since: now), sortableArticleID: "1", sortableFeedID: "3")
		let article5 = TestArticle(sortableName: "Gordy's Blog", sortableDate: Date(timeInterval: -10.0, since: now), sortableArticleID: "2", sortableFeedID: "3")
		let article6 = TestArticle(sortableName: "Jenny's Feed", sortableDate: Date(timeInterval: 10.0, since: now), sortableArticleID: "3", sortableFeedID: "2")
		let article7 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "1")
		let article8 = TestArticle(sortableName: "Zippy's Feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "0")
		let article9 = TestArticle(sortableName: "Zippy's Feed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "0")
		
		let articles = [article1, article2, article3, article4, article5, article6, article7, article8, article9]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles, sortDirection: .orderedDescending, groupByFeed: true)
		
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
		
		let article1 = TestArticle(sortableName: "phil's feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "1")
		let article2 = TestArticle(sortableName: "PhIl's FEed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "1")
		let article3 = TestArticle(sortableName: "APPLE's feed", sortableDate: now, sortableArticleID: "3", sortableFeedID: "2")
		let article4 = TestArticle(sortableName: "PHIL'S FEED", sortableDate: now, sortableArticleID: "4", sortableFeedID: "1")
		let article5 = TestArticle(sortableName: "apple's feed", sortableDate: now, sortableArticleID: "5", sortableFeedID: "2")

		let articles = [article1, article2, article3, article4, article5]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedAscending,
														groupByFeed: true)

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
		let article1 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "1", sortableFeedID: "2")
		let article2 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "2", sortableFeedID: "2")
		let article3 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "3", sortableFeedID: "1")
		let article4 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "4", sortableFeedID: "2")
		let article5 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableArticleID: "5", sortableFeedID: "1")

		let articles = [article1, article2, article3, article4, article5]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedAscending,
														groupByFeed: true)

		XCTAssertEqual(sortedArticles.count, articles.count)
		XCTAssertEqual(sortedArticles.articleAtRow(0), article3)
		XCTAssertEqual(sortedArticles.articleAtRow(1), article5)
		XCTAssertEqual(sortedArticles.articleAtRow(2), article1)
		XCTAssertEqual(sortedArticles.articleAtRow(3), article2)
		XCTAssertEqual(sortedArticles.articleAtRow(4), article4)
	}
					
}

private struct TestArticle: SortableArticle, Equatable {
	let sortableName: String
	let sortableDate: Date
	let sortableArticleID: String
	let sortableFeedID: String
}

private extension Array where Element == TestArticle {
	func articleAtRow(_ row: Int) -> TestArticle? {
		if row < 0 || row == NSNotFound || row > count - 1 {
			return nil
		}
		return self[row]
	}
	
}
