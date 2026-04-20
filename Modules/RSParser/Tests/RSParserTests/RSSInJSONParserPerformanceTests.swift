//
//  RSSInJSONParserPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
import RSParser

// Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }` equivalent yet.

final class RSSInJSONParserPerformanceTests: XCTestCase {

	func testScriptingNewsPerformance() {
		// 0.003 sec on my 2012 iMac.
		let d = parserData("ScriptingNews", "json", "http://scripting.com/")
		self.measure {
			_ = try! FeedParser.parse(d)
		}
	}
}
