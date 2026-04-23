//
//  EntityDecodingPerformanceTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSParser

/// Performance baseline for `String.decodingHTMLEntities`.
///
/// "Legacy" was the Objective-C `NSScanner` implementation
/// (`rsparser_stringByDecodingHTMLEntities`) that shipped to
/// customers up until the Swift port.
///
/// The final row is the one to quote as the overall customer-visible
/// speedup since it’s for a mix.
///
/// Benchmark: release build, Apple Silicon — mean per-call time.
///
/// Large clean body (~100 KB, no entities — the common fast path):
///     Legacy (ObjC NSScanner):   0.000847 seconds/call
///     New (pure Swift):          0.000018 seconds/call
///     Speedup:                   ~47×
///
/// Mostly-clean large body (~100 KB, two entities near the start):
///     Legacy:                    0.000194 seconds/call
///     New:                       0.000077 seconds/call
///     Speedup:                   ~2.5×
///
/// Actually dirty large body (~80 KB, ~4000 mixed entities):
///     Legacy:                    0.006567 seconds/call
///     New:                       0.000256 seconds/call
///     Speedup:                   ~26×
///
/// Short clean titles (title path, no entities):
///     Legacy:                    0.00000094 seconds/call
///     New:                       0.00000002 seconds/call
///     Speedup:                   ~42×
///
/// Mix (10 articles: 10 titles + 3 clean + 6
/// mostly-clean + 3 dirty bodies):
///     Legacy:                    0.001055 seconds/call
///     New:                       0.000058 seconds/call
///     Speedup:                   ~18×
final class EntityDecodingPerformanceTests: XCTestCase {

	// MARK: - Fixtures

	// A realistic article-body-sized chunk of HTML with no `&` in it
	// — i.e. the common fast-path case. At ~100 KB it's comparable
	// to a long blog post.
	private static let cleanLargeBody: String = {
		let paragraph = "<p>This is a sample paragraph of article body text that has no entities in it whatsoever. It exists purely to be long enough to exercise the no-match fast path of decodingHTMLEntities on a realistic-scale input — the kind of body text NetNewsWire might see thousands of times per scroll session.</p>"
		return String(repeating: paragraph, count: 250) // ~100 KB
	}()

	// Large body with only two entities, both near the start.
	// Exercises the slow path but most of the scan is work-free.
	private static let mostlyCleanLargeBody: String = {
		let prefix = "<p>Tom &amp; Jerry run a test &mdash; "
		let paragraph = "the body continues without any further entities for a good long while to exercise the post-ampersand slow path scanning </p>"
		return prefix + String(repeating: paragraph, count: 250)
	}()

	// Large body that is densely and continuously dirty: every
	// paragraph has ~16 entities of mixed kinds (named, numeric
	// decimal, numeric hex).
	private static let actuallyDirtyLargeBody: String = {
		let paragraph = "<p>Tom &amp; Jerry (est. 1940 &copy; Hanna-Barbera) &mdash; the &quot;classic&quot; duo. Caf&eacute; &ndash; M&uuml;nchen &hellip; &laquo;chase scenes&raquo; and &apos;mouse traps&apos; (&#8220;clever&#8221; &#x2014; sometimes &#169; licensed).</p>"
		return String(repeating: paragraph, count: 250) // ~80 KB, ~4,000 entities
	}()

	// Short clean titles — what `ArticleStringFormatter`'s title
	// path sees on every timeline row.
	private static let shortCleanTitles: [String] = [
		"Simple plain title",
		"Another title with only punctuation and spaces",
		"Unicode title with emoji and accents café résumé",
		"A long title with many words but still no entities anywhere inside"
	]

	// Realistic per-batch workload: 10 articles worth of input.
	private static let realisticMixBatch: [String] = {
		var batch: [String] = []
		// 10 titles (one per article)
		for i in 0..<10 {
			batch.append(shortCleanTitles[i % shortCleanTitles.count])
		}
		// 3 clean bodies
		for _ in 0..<3 {
			batch.append(cleanLargeBody)
		}
		// 6 mostly-clean bodies
		for _ in 0..<6 {
			batch.append(mostlyCleanLargeBody)
		}
		// 3 dirty bodies
		for _ in 0..<3 {
			batch.append(actuallyDirtyLargeBody)
		}
		return batch
	}()

	// MARK: - Benchmarks

	func testLargeCleanBody() {
		let body = Self.cleanLargeBody
		var checksum = 0
		measure {
			for _ in 0..<1000 {
				checksum &+= body.decodingHTMLEntities().utf8.count
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}

	func testMostlyCleanLargeBody() {
		let body = Self.mostlyCleanLargeBody
		var checksum = 0
		measure {
			for _ in 0..<1000 {
				checksum &+= body.decodingHTMLEntities().utf8.count
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}

	func testActuallyDirtyLargeBody() {
		let body = Self.actuallyDirtyLargeBody
		var checksum = 0
		measure {
			for _ in 0..<1000 {
				checksum &+= body.decodingHTMLEntities().utf8.count
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}

	func testShortCleanTitles() {
		let titles = Self.shortCleanTitles
		var checksum = 0
		measure {
			for _ in 0..<100_000 {
				for title in titles {
					checksum &+= title.decodingHTMLEntities().utf8.count
				}
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}

	// 50 batches × 22 calls/batch = 1100 calls per measure iteration.
	// Each batch is 10 titles + 3 clean + 6 mostly-clean + 3 dirty bodies.
	func testRealisticMix() {
		let batch = Self.realisticMixBatch
		var checksum = 0
		measure {
			for _ in 0..<50 {
				for input in batch {
					checksum &+= input.decodingHTMLEntities().utf8.count
				}
			}
		}
		XCTAssertGreaterThan(checksum, 0)
	}
}
