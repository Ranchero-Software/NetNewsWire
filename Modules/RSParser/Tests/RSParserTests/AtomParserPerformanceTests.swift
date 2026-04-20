//
//  AtomParserPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
import RSParser

// Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }` equivalent yet.

final class AtomParserPerformanceTests: XCTestCase {

	func testDaringFireballPerformance() {
		// 0.009 sec on my 2012 iMac.
		let d = parserData("DaringFireball", "atom", "https://daringfireball.net/feeds/main")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}

	func testAllThisPerformance() {
		// 0.003 sec on my 2012 iMac.
		let d = parserData("allthis", "atom", "http://leancrew.com/all-this")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}
}
