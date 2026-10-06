//
//  SanitizedTitlePerformanceTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import XCTest

@testable import NetNewsWire

/// Performance baseline for `ArticleStringFormatter.sanitizedTitle(_:forHTML:)`.
///
/// Benchmark: release build, M1 Studio. Mean per-call time across
/// a mix of eight titles, with `forHTML=true` and `forHTML=false`
///
///     Scanner-based (old):  0.00000955 seconds/call
///     Byte-level (current): 0.00000043 seconds/call
///     Speedup:              ~22×
///
/// (The old Scanner-based implementation has been deleted.)
final class SanitizedTitlePerformanceTests: XCTestCase {

	private static let titles: [String] = [
		"Simple plain title",
		"Title with <b>bold</b> and <i>italic</i> words inline",
		"Mixed <b>allowed</b> and <script>disallowed</script> tags",
		"Title with entities &amp; ampersand and &lt;escaped&gt; text",
		"Long title that stretches on and on without any tags at all",
		"Unicode title with emoji 🎉 and accents café résumé",
		"<b>Full-tag</b> <em>title</em> with <code>multiple</code> inline tags",
		"A somewhat longer realistic title mentioning iOS, macOS, and watchOS updates"
	]

	func testSanitizedTitle() {
		let titles = Self.titles
		var checksum = 0
		measure {
			for _ in 0..<10_000 {
				for title in titles {
					if let s = ArticleStringFormatter.sanitizedTitle(title, forHTML: true) {
						checksum &+= s.utf8.count
					}
					if let s = ArticleStringFormatter.sanitizedTitle(title, forHTML: false) {
						checksum &+= s.utf8.count
					}
				}
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}
}
