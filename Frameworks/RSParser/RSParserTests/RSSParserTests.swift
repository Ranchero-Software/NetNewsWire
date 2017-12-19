//
//  RSSParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class RSSParserTests: XCTestCase {

	func testScriptingNewsPerformance() {

		// 0.004 sec on my 2012 iMac.
		let d = parserData("scriptingNews", "rss", "http://scripting.com/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testKatieFloydPerformance() {

		// 0.004 sec on my 2012 iMac.
		let d = parserData("KatieFloyd", "rss", "http://katiefloyd.com/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testEMarleyPerformance() {

		// 0.001 sec on my 2012 iMac.
		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testMantonPerformance() {

		// 0.002 sec on my 2012 iMac.
		let d = parserData("manton", "rss", "http://manton.org/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testNatashaTheRobot() {

		let d = parserData("natasha", "xml", "https://www.natashatherobot.com/")
		let parsedFeed = try! FeedParser.parse(d)!
		XCTAssertEqual(parsedFeed.items.count, 10)
	}

	func testTheOmniShowAttachments() {

		let d = parserData("theomnishow", "rss", "https://theomnishow.omnigroup.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotNil(article.attachments)
			XCTAssertEqual(article.attachments!.count, 1)
			let attachment = Array(article.attachments!).first!
			XCTAssertNotNil(attachment.mimeType)
			XCTAssertNotNil(attachment.sizeInBytes)
			XCTAssert(attachment.url.contains("cloudfront"))
			XCTAssertGreaterThanOrEqual(attachment.sizeInBytes!, 22275279)
			XCTAssertEqual(attachment.mimeType, "audio/mpeg")
		}
	}

	func testTheOmniShowUniqueIDs() {

		let d = parserData("theomnishow", "rss", "https://theomnishow.omnigroup.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotNil(article.uniqueID)
			XCTAssertTrue(article.uniqueID.hasPrefix("https://theomnishow.omnigroup.com/episode/"))
		}
	}

	func testMacworldUniqueIDs() {

		// Macworld’s feed doesn’t have guids, so they should be calculated unique IDs.

		let d = parserData("macworld", "rss", "https://www.macworld.com/")
		let parsedFeed = try! FeedParser.parse(d)!

		for article in parsedFeed.items {
			XCTAssertNotNil(article.uniqueID)
			XCTAssertEqual(article.uniqueID.count, 32) // calculated unique IDs are MD5 hashes
		}

	}
}
