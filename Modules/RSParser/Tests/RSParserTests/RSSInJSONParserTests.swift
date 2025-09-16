//
//  RSSInJSONParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

final class RSSInJSONParserTests: XCTestCase {

	func testScriptingNewsPerformance() {

		// 0.003 sec on my 2012 iMac.
		let d = parserData("ScriptingNews", "json", "http://scripting.com/")
		self.measure {
			let _ = try! FeedParser.parse(d)
		}
	}

	func testFeedLanguage() {
		let d = parserData("ScriptingNews", "json", "http://scripting.com/")
		let parsedFeed = try! FeedParser.parse(d)!
		XCTAssertEqual(parsedFeed.language, "en-us")
	}
}
