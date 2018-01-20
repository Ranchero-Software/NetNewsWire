//
//  StringTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 1/13/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import XCTest

class StringTests: XCTestCase {

    func testURLQueryEncoding() {

		var s = "foo".encodedForURLQuery()
		XCTAssertEqual(s, "foo")

		s = "foo bar".encodedForURLQuery()
		XCTAssertEqual(s, "foo%20bar")

		s = "foo bar &well".encodedForURLQuery()
		XCTAssertEqual(s, "foo%20bar%20%38well")
    }
}
