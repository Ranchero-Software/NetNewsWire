//
//  RSSInJSONParserTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/26/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSParser

@Suite struct RSSInJSONParserTests {

	@Test func feedLanguage() throws {
		let d = parserData("ScriptingNews", "json", "http://scripting.com/")
		let parsedFeed = try #require(try FeedParser.parse(d))
		#expect(parsedFeed.language == "en-us")
	}
}
