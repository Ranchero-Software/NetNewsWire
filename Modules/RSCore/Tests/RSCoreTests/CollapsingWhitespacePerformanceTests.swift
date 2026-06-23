//
//  CollapsingWhitespacePerformanceTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSCore

/// Performance baseline for `String.collapsingWhitespace`.
///
/// Benchmark: release build, Apple Silicon — mean
/// per-call time across a mix of titles:
///
///     Regex-based (legacy):   0.00000357 seconds/call
///     Byte-level (current):   0.00000021 seconds/call
///     Speedup:                ~17×
final class CollapsingWhitespacePerformanceTests: XCTestCase {

	private static let titles: [String] = [
		"Simple clean title",
		"Title   with   multiple   spaces",
		"  Leading and trailing whitespace  ",
		"Mixed\twhitespace\ntypes\r\n",
		"Title\n\nwith\t\tdouble\r\nwhitespace\n\n",
		"Unicode title with emoji 🎉 and accents café résumé",
		"This is a considerably longer title that has many words in it but no excess whitespace",
		"A short one"
	]

	func testCollapsingWhitespace() {
		var checksum = 0
		measure {
			for _ in 0..<100_000 {
				for title in Self.titles {
					checksum &+= title.collapsingWhitespace.utf8.count
				}
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}
}
