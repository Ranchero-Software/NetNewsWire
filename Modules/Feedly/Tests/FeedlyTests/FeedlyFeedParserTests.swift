//
//  FeedlyFeedParserTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 29/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Feedly

final class FeedlyFeedParserTests: XCTestCase {

	func testParsing() {
		let name = "Test Feed"
		let website = "tests://nnw/feed/1"
		let url = "tests://nnw/feed.xml"
		let id = "feed/\(url)"
		let updated = Date.distantPast
		let feed = FeedlyFeed(id: id, title: name, updated: updated, website: website)
		let parser = FeedlyFeedParser(feed: feed)
		XCTAssertEqual(parser.title, name)
		XCTAssertEqual(parser.homePageURL, website)
		XCTAssertEqual(parser.url, url)
		XCTAssertEqual(parser.feedID, id)
	}
	
	func testSanitization() {
		let name = "Test Feed"
		let website = "tests://nnw/feed/1"
		let url = "tests://nnw/feed.xml"
		let id = "feed/\(url)"
		let updated = Date.distantPast
		let feed = FeedlyFeed(id: id, title: "<div style=\"direction:rtl;text-align:right\">\(name)</div>", updated: updated, website: website)
		let parser = FeedlyFeedParser(feed: feed)
		XCTAssertEqual(parser.title, name)
		XCTAssertEqual(parser.homePageURL, website)
		XCTAssertEqual(parser.url, url)
		XCTAssertEqual(parser.feedID, id)
	}
}
