//
//  AtomParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class AtomParserTests: XCTestCase {

	func testDaringFireballPerformance() {

		// 0.009 sec on my 2012 iMac.
		let d = parserData("DaringFireball", "atom", "http://daringfireball.net/") //It’s actually an Atom feed
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testAllThisPerformance() {

		// 0.003 sec on my 2012 iMac.
		let d = parserData("allthis", "atom", "http://leancrew.com/all-this")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testGettingHomePageLink() {

		let d = parserData("allthis", "atom", "http://leancrew.com/all-this")
		let parsedFeed = try! FeedParser.parse(d)!

		XCTAssertTrue(parsedFeed.homePageURL == "http://leancrew.com/all-this")
	}
}
