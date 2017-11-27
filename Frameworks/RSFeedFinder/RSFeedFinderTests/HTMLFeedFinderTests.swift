//
//  HTMLFeedFinderTests.swift
//  RSFeedFinder
//
//  Created by Brent Simmons on 8/7/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSFeedFinder
import RSParser

class HTMLFeedFinderTests: XCTestCase {

	func parserData(_ filename: String, _ fileExtension: String, _ url: String) -> ParserData {

		let bundle = Bundle(for: HTMLFeedFinderTests.self)
		let path = bundle.path(forResource: filename, ofType: fileExtension)!
		let data = try! Data(contentsOf: URL(fileURLWithPath: path))
		return ParserData(url: url, data: data)
	}

	func feedFinder(_ fileName: String, _ fileExtension: String, _ url: String) -> HTMLFeedFinder {

		let d = parserData(fileName, fileExtension, url)
		return HTMLFeedFinder(parserData: d)
	}

	func testPerformanceWithDaringFireball() {

		let d = parserData("DaringFireball", "html", "https://daringfireball.net/")
		self.measure {

			let finder = HTMLFeedFinder(parserData: d)
			let _ = finder.feedSpecifiers
		}
	}

	func testFindingBestFeedWithDaringFireBall() {

		let finder = feedFinder("DaringFireball", "html", "https://daringfireball.net/")
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers)!
		XCTAssert(bestFeedSpecifier.urlString == "https://daringfireball.net/feeds/json")
	}

	func testFindingBestFeedWithFurbo() {

		let finder = feedFinder("furbo", "html", "http://furbo.org")
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers)!
		XCTAssert(bestFeedSpecifier.urlString == "http://furbo.org/feed/")
	}

	func testFindingBestFeedWithIndieStack() {

		let finder = feedFinder("indiestack", "html", "http://indiestack.com/")
		let feedSpecifiers = finder.feedSpecifiers
		let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers)!
		XCTAssert(bestFeedSpecifier.urlString == "http://indiestack.com/feed/json/")
	}

}



