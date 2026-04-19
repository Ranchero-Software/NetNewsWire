//
//  MD5PerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//
//  Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }`
//  equivalent yet.

import XCTest
@testable import RSParser

final class MD5PerformanceTests: XCTestCase {

	/// Benchmark the md5String hot path with feed-guid-sized inputs (calculated
	/// article uniqueIDs: concatenations of permalink + date, ~60–120 bytes typically).
	func testMD5HexPerformance() {
		let inputs = (0..<1000).map { i in
			"https://example.com/article/\(i)1234567890"
		}
		self.measure {
			for s in inputs {
				_ = s.md5String
			}
		}
	}
}
