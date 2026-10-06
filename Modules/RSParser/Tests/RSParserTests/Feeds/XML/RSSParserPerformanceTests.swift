//
//  RSSParserPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
import RSParser

// Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }` equivalent yet.

final class RSSParserPerformanceTests: XCTestCase {

	func testScriptingNewsPerformance() {
		// 0.004 sec on my 2012 iMac.
		let d = parserData("scriptingNews", "rss", "http://scripting.com/")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}

	func testKatieFloydPerformance() {
		// 0.004 sec on my 2012 iMac.
		let d = parserData("KatieFloyd", "rss", "http://katiefloyd.com/")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}

	func testEMarleyPerformance() {
		// 0.001 sec on my 2012 iMac.
		let d = parserData("EMarley", "rss", "https://medium.com/@emarley")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}

	func testMantonPerformance() {
		// 0.002 sec on my 2012 iMac.
		let d = parserData("manton", "rss", "http://manton.org/")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}
}
