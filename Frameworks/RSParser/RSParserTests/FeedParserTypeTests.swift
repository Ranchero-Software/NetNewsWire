//
//  FeedParserTypeTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class FeedParserTypeTests: XCTestCase {

	// MARK: HTML

	func testDaringFireballHTMLType() {

		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .notAFeed)
	}

	func testFurboHTMLType() {

		let d = parserData("furbo", "html", "http://furbo.org/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .notAFeed)
	}
	
	func testInessentialHTMLType() {

		let d = parserData("inessential", "html", "http://inessential.com/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .notAFeed)
	}

	func testSixColorsHTMLType() {

		let d = parserData("sixcolors", "html", "https://sixcolors.com/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .notAFeed)
	}
	
	// MARK: RSS

	func testEMarleyRSSType() {

		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .rss)
	}

	func testScriptingNewsRSSType() {

		let d = parserData("scriptingNews", "rss", "http://scripting.com/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .rss)
	}
	
	func testKatieFloydRSSType() {

		let d = parserData("KatieFloyd", "rss", "https://katiefloyd.com/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .rss)
	}

	func testMantonRSSType() {

		let d = parserData("manton", "rss", "http://manton.org/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .rss)
	}

	// MARK: Atom

	func testDaringFireballAtomType() {

		// File extension is .rss, but it’s really an Atom feed.
		let d = parserData("DaringFireball", "rss", "http://daringfireball.net/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .atom)
	}

	func testOneFootTsunamiAtomType() {

		let d = parserData("OneFootTsunami", "atom", "http://onefoottsunami.com/")
		let type = FeedParser.feedType(d)
		XCTAssertTrue(type == .atom)
	}

	// MARK: Performance
	
	func testFeedTypePerformance() {

		// I get 0.000079 on my 2012 iMac. feedType is fast, at least in this case.

		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		self.measure {
			let _ = FeedParser.feedType(d)
		}
	}
}

func parserData(_ filename: String, _ fileExtension: String, _ url: String) -> ParserData {

	let bundle = Bundle(for: FeedParserTypeTests.self)
	let path = bundle.path(forResource: filename, ofType: fileExtension)!
	let data = try! Data(contentsOf: URL(fileURLWithPath: path))
	return ParserData(url: url, data: data)
}
