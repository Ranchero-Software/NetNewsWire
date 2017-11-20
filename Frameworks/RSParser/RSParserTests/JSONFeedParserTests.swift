//
//  JSONFeedParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class JSONFeedParserTests: XCTestCase {

	func testInessentialPerformance() {

		// 0.001 sec on my 2012 iMac.
		let d = parserData("inessential", "json", "http://inessential.com/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testDaringFireballPerformance() {

		// 0.009 sec on my 2012 iMac.
		let d = parserData("DaringFireball", "json", "http://daringfireball.net/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testThatEntitiesAreDecoded() {

		let d = parserData("DaringFireball", "json", "http://daringfireball.net/")
		let parsedFeed = try! FeedParser.parse(d)

		// https://github.com/brentsimmons/Evergreen/issues/176
		// In the article titled "The Talk Show: ‘I Do Like Throwing a Baby’",
		// make sure the content HTML starts with "\n<p>New episode of America’s"
		// instead of "\n<p>New episode of America&#8217;s" — this will tell us
		// that entities are being decoded.

		for article in parsedFeed!.items {
			if article.title == "The Talk Show: ‘I Do Like Throwing a Baby’" {
				XCTAssert(article.contentHTML!.hasPrefix("\n<p>New episode of America’s"))
				return
			}
		}

		XCTAssert(false, "Expected to find “The Talk Show: ‘I Do Like Throwing a Baby’” article.")
	}

}
