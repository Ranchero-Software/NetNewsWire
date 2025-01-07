//
//  StringTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 1/13/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import XCTest

class StringTests: XCTestCase {

    func testHTMLEscaping() {

		let s = #"<foo>"bar"&'baz'"#.escapedHTML
		XCTAssertEqual(s, "&lt;foo&gt;&quot;bar&quot;&amp;&apos;baz&apos;")

    }
}
