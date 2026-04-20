//
//  OPMLPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
import RSParser
import RSParserObjC

// Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }` equivalent yet.

final class OPMLPerformanceTests: XCTestCase {

	func testOPMLParsingPerformance() {
		// 0.002 sec on my 2012 iMac.
		let subsData = parserData("Subs", "opml", "http://example.org/")
		self.measure {
			_ = try! RSOPMLParser.parseOPML(with: subsData)
		}
	}
}
