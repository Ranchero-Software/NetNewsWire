//
//  NSAttributedStringHTMLPerformanceTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import XCTest

@testable import NetNewsWire

/// Performance baseline for `NSAttributedString(simpleHTML:)`.
///
/// Benchmark: release build, Apple Silicon — mean per-call time
/// across a mix of eight representative titles (plain, with inline
/// tags, with entities, with long text runs):
///
///     Pre-optimization:         0.00003546 seconds/call
///     Current:                  0.00000636 seconds/call
///     Speedup:                  ~5.6×
@MainActor final class NSAttributedStringHTMLPerformanceTests: XCTestCase {

	private static let titles: [String] = [
		"Simple plain title with no tags or entities at all",
		"Use <b>bold</b> text in the middle",
		"<b>Bold</b> and <i>italic</i> and <code>code</code>",
		"Tom &amp; Jerry run a race",
		"<b>Long bold run</b> with a lot of text inside the tag",
		"Mix <b>bold</b>, <i>italic</i>, <u>underline</u>, and <code>code</code>",
		"Unicode title with emoji 🎉 and café résumé",
		"A considerably longer title that has many words in it and exercises the happy path of a long text run being appended to the NSMutableAttributedString"
	]

	private static let locale = Locale(identifier: "en_US")

	func testBuildAttributedString() {
		let titles = Self.titles
		let locale = Self.locale
		var checksum = 0
		measure {
			for _ in 0..<10_000 {
				for title in titles {
					let a = NSAttributedString(simpleHTML: title, locale: locale)
					checksum &+= a.length
				}
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}
}
