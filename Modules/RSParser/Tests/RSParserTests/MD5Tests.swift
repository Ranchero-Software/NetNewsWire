//
//  MD5Tests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import Foundation
import XCTest
@testable import RSParser

final class MD5Tests: XCTestCase {

	// MARK: - Correctness

	func testEmptyString() {
		XCTAssertEqual("".md5String, "d41d8cd98f00b204e9800998ecf8427e")
	}

	func testKnownVectors() {
		XCTAssertEqual("abc".md5String, "900150983cd24fb0d6963f7d28e17f72")
		XCTAssertEqual("The quick brown fox jumps over the lazy dog".md5String,
		               "9e107d9d372bb6826bd81d3542a419d6")
	}

	func testFormatIs32LowercaseHex() {
		let hash = "arbitrary input".md5String
		XCTAssertEqual(hash.count, 32)
		XCTAssertTrue(hash.allSatisfy { c in
			("0"..."9").contains(c) || ("a"..."f").contains(c)
		})
	}

	// MARK: - Performance

	/// Benchmark the md5String hot path with feed-guid-sized inputs (calculated article
	/// uniqueIDs: concatenations of permalink + date, ~60-120 bytes typically).
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
