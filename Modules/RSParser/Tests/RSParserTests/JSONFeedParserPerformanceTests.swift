//
//  JSONFeedParserPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//
//  Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }`
//  equivalent yet.
//

import XCTest
import RSParser

final class JSONFeedParserPerformanceTests: XCTestCase {

	func testInessentialPerformance() {
		// 0.001 sec on my 2012 iMac.
		let d = parserData("inessential", "json", "http://inessential.com/")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}

	func testDaringFireballPerformance() {
		// 0.009 sec on my 2012 iMac.
		let d = parserData("DaringFireball", "json", "http://daringfireball.net/")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}
}
