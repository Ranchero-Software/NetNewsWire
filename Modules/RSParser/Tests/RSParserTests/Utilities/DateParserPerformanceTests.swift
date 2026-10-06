//
//  DateParserPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
@testable import RSParser

// Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }` equivalent yet.

final class DateParserPerformanceTests: XCTestCase {

	/// Byte-slice hot path with a mix of pubDate and W3C formats, including one
	/// that hits the timezone-abbreviation dictionary.
	func testHotPathPerformance() {
		let inputs = [
			"Fri, 28 May 2010 21:03:38 GMT",
			"2010-05-28T21:03:38+00:00",
			"Sun, 12 Apr 2026 17:24:19 +0000",
			"2021-03-29T10:46:56.516941+00:00",
			"Wed, 09 Jun 2010 00:00 EST",
			"2010-11-17T08:40:07-05:00"
		].map { ArraySlice(Array($0.utf8)) }

		self.measure {
			for _ in 0..<5000 {
				for bytes in inputs {
					_ = DateParser.date(bytes: bytes)
				}
			}
		}
	}
}
