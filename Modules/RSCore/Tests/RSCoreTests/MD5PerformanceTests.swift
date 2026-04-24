//
//  MD5PerformanceTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 4/19/26.
//

import XCTest
@testable import RSCore

// Performance tests stay in XCTest — Swift Testing doesn't have a `measure { }` equivalent yet.

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
