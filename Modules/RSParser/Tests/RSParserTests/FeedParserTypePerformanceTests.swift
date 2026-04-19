//
//  FeedParserTypePerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//
//  Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }`
//  equivalent yet.
//

import XCTest
import RSParser

final class FeedParserTypePerformanceTests: XCTestCase {

	func testFeedTypePerformance() {
		// 0.000 on my 2012 iMac.
		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		self.measure {
			_ = feedType(d)
		}
	}

	func testFeedTypePerformance2() {
		// 0.000 on my 2012 iMac.
		let d = parserData("inessential", "json", "http://inessential.com/")
		self.measure {
			_ = feedType(d)
		}
	}

	func testFeedTypePerformance3() {
		// 0.000 on my 2012 iMac.
		let d = parserData("DaringFireball", "html", "http://daringfireball.net/")
		self.measure {
			_ = feedType(d)
		}
	}

	func testFeedTypePerformance4() {
		// 0.001 on my 2012 iMac.
		let d = parserData("DaringFireball", "rss", "http://daringfireball.net/")
		self.measure {
			_ = feedType(d)
		}
	}
}
