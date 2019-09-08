//
//  ArticleArrayTests.swift
//  NetNewsWire
//
//  Created by Phil Viso on 9/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Articles
import Foundation
import XCTest

@testable import NetNewsWire

class ArticleArrayTests: XCTestCase {
	
	func testSortByDateAscending() {
		let now = Date()
		
		// Test data includes a mixture of articles in the past and future, as well as articles with the same date
		let article1 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableID: "456")
		let article2 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "789")
		let article3 = TestArticle(sortableName: "Sally's Feed", sortableDate: now, sortableID: "123")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableID: "345")
		let article5 = TestArticle(sortableName: "Paul's Feed", sortableDate: Date(timeInterval: -120.0, since: now), sortableID: "567")
		let article6 = TestArticle(sortableName: "phil's Feed", sortableDate: Date(timeInterval: 60.0, since: now), sortableID: "567")
		
		let articles = [article1, article2, article3, article4, article5, article6]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedAscending,
														groupByFeed: false)
		XCTAssertEqual(sortedArticles, [article5, article4, article3, article1, article2, article6])
	}
	
	func testSortByDateAscendingWithGroupByFeed() {
		let now = Date()
		
		// Test data includes multiple groups (with case-insentive names), articles in the past and future,
		// as well as articles with the same date
		let article1 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -240.0, since: now), sortableID: "123")
		let article2 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableID: "456")
		let article3 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "234")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -120.0, since: now), sortableID: "123")
		let article5 = TestArticle(sortableName: "phil's feed", sortableDate: Date(timeInterval: 60.0, since: now), sortableID: "456")
		let article6 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "123")
		let article7 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableID: "123")
		let article8 = TestArticle(sortableName: "phil's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableID: "456")
		let article9 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "345")
		let article10 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -15.0, since: now), sortableID: "123")
		let article11 = TestArticle(sortableName: "Matt's Feed", sortableDate: Date(timeInterval: 60.0, since: now), sortableID: "123")
		let article12 = TestArticle(sortableName: "Claire's Feed", sortableDate: now, sortableID: "123")
		
		let articles = [article1, article2, article3, article4, article5, article6, article7, article8, article9, article10, article11, article12]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedAscending,
														groupByFeed: true)
		XCTAssertEqual(sortedArticles, [article12, article6, article3, article9, article11, article8, article2, article5, article1, article4, article7, article10])
	}
	
	func testSortByDateDescending() {
		let now = Date()
		
		// Test data includes a mixture of articles in the past and future, as well as articles with the same date
		let article1 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableID: "456")
		let article2 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "789")
		let article3 = TestArticle(sortableName: "Sally's Feed", sortableDate: now, sortableID: "123")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableID: "345")
		let article5 = TestArticle(sortableName: "Paul's Feed", sortableDate: Date(timeInterval: -120.0, since: now), sortableID: "567")
		let article6 = TestArticle(sortableName: "phil's Feed", sortableDate: Date(timeInterval: 60.0, since: now), sortableID: "567")
		
		let articles = [article1, article2, article3, article4, article5, article6]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedDescending,
														groupByFeed: false)
		XCTAssertEqual(sortedArticles, [article6, article3, article1, article2, article4, article5])
	}
	
	func testSortByDateDescendingWithGroupByFeed() {
		let now = Date()
		
		// Test data includes multiple groups (with case-insentive names), articles in the past and future,
		// as well as articles with the same date
		let article1 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -240.0, since: now), sortableID: "123")
		let article2 = TestArticle(sortableName: "Phil's Feed", sortableDate: now, sortableID: "456")
		let article3 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "234")
		let article4 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -120.0, since: now), sortableID: "123")
		let article5 = TestArticle(sortableName: "phil's feed", sortableDate: Date(timeInterval: 60.0, since: now), sortableID: "456")
		let article6 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "123")
		let article7 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableID: "123")
		let article8 = TestArticle(sortableName: "phil's Feed", sortableDate: Date(timeInterval: -60.0, since: now), sortableID: "456")
		let article9 = TestArticle(sortableName: "Matt's Feed", sortableDate: now, sortableID: "345")
		let article10 = TestArticle(sortableName: "Susie's Feed", sortableDate: Date(timeInterval: -15.0, since: now), sortableID: "123")
		let article11 = TestArticle(sortableName: "Matt's Feed", sortableDate: Date(timeInterval: 60.0, since: now), sortableID: "123")
		let article12 = TestArticle(sortableName: "Claire's Feed", sortableDate: now, sortableID: "123")
		
		let articles = [article1, article2, article3, article4, article5, article6, article7, article8, article9, article10, article11, article12]
		let sortedArticles = ArticleSorter.sortedByDate(articles: articles,
														sortDirection: .orderedDescending,
														groupByFeed: true)
		XCTAssertEqual(sortedArticles, [article12, article11, article6, article3, article9, article5, article2, article8, article10, article7, article4, article1])
	}
				
}

private struct TestArticle: SortableArticle, Equatable {
	let sortableName: String
	let sortableDate: Date
	let sortableID: String
}
