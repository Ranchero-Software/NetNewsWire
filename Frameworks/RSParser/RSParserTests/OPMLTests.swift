//
//  OPMLTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSParser

class OPMLTests: XCTestCase {

	func testOPMLParsingPerformance() {

		let d = parserData("Subs", "opml", "http://example.org/")
		self.measure {
			let _ = try! RSOPMLParser.parseOPML(with: d)
		}
	}

}
