//
//  ArticleStringFormatterPerformanceTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Articles
import Foundation
import RSCore
import RSParser
import XCTest

@testable import NetNewsWire

/// Each test uses a fresh formatter per pass so every call hits the
/// code path (not the cache).
///
/// Benchmark: release build, Apple Silicon — mean per-call time
/// captured at the point the legacy implementations were deleted:
///
///     Function                   Legacy          Current         Speedup
///     -------------------------  ------------    ------------    -------
///     truncatedFeedName          0.00000048 s    0.00000040 s    ~1.2×
///     truncatedTitle             0.00000060 s    0.00000024 s    ~2.5×
///     attributedTruncatedTitle   0.00000580 s    0.00000055 s    ~11×
///     truncatedSummary           0.00001200 s    0.00000102 s    ~12×
///
@MainActor final class ArticleStringFormatterPerformanceTests: XCTestCase {

	private static let articles: [Article] = makePerformanceTestArticles()
	private static let feedNames: [String] = makePerformanceTestFeedNames()

	func testTruncatedFeedName() {
		measure {
			for _ in 0..<1000 {
				let formatter = ArticleStringFormatter()
				for name in Self.feedNames {
					_ = formatter.truncatedFeedName(name)
				}
			}
		}
	}

	func testTruncatedTitle() {
		measure {
			for _ in 0..<1000 {
				let formatter = ArticleStringFormatter()
				for article in Self.articles {
					_ = formatter.truncatedTitle(article, forHTML: true)
					_ = formatter.truncatedTitle(article, forHTML: false)
				}
			}
		}
	}

	func testAttributedTruncatedTitle() {
		measure {
			for _ in 0..<1000 {
				let formatter = ArticleStringFormatter()
				for article in Self.articles {
					_ = formatter.attributedTruncatedTitle(article)
				}
			}
		}
	}

	func testTruncatedSummary() {
		measure {
			for _ in 0..<1000 {
				let formatter = ArticleStringFormatter()
				for article in Self.articles {
					_ = formatter.truncatedSummary(article)
				}
			}
		}
	}
}

// MARK: - Fixtures

@MainActor private func makePerformanceTestArticles() -> [Article] {
	let count = 100
	let sampleTitles = [
		"Simple plain title",
		"Title with <b>bold</b> and <i>italic</i> and <code>code</code>",
		"Title with entities &amp; ampersand and &quot;quotes&quot; and &lt;tags&gt;",
		"Long title with lots of words that stretches on and on for quite a while before ending",
		"Unicode title with emoji 🎉 and accents café résumé",
		"Title with\nnewlines\tand\ttabs"
	]
	let entityParagraph = "<p>Tom &amp; Jerry run a test &mdash; the body continues without any further entities for a good long while to exercise the post-ampersand slow path scanning across a realistic-scale article body.</p>"
	let loremParagraph = "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>"
	let sampleBodies = [
		"<p>A short article body with no entities at all.</p>",
		"<html><body><p>Paragraph with <b>bold</b>, <i>italic</i>, and <a href=\"#\">links</a>.</p><p>Second paragraph with &amp; entities &lt;tags&gt; and more content.</p><script>alert('ignored');</script></body></html>",
		String(repeating: entityParagraph, count: 100),
		String(repeating: loremParagraph, count: 100),
		"<p>Comments</p>"
	]
	var result: [Article] = []
	result.reserveCapacity(count)
	for i in 0..<count {
		let title = sampleTitles[i % sampleTitles.count]
		let body = sampleBodies[i % sampleBodies.count]
		let status = ArticleStatus(articleID: "article\(i)", read: false, starred: false, dateArrived: Date())
		let article = Article(
			accountID: "account1",
			articleID: "article\(i)",
			feedID: "feed1",
			uniqueID: "unique\(i)",
			title: title,
			contentHTML: body,
			contentText: nil,
			markdown: nil,
			url: nil,
			externalURL: nil,
			summary: nil,
			imageURL: nil,
			datePublished: Date(),
			dateModified: nil,
			authors: nil,
			status: status
		)
		result.append(article)
	}
	return result
}

private func makePerformanceTestFeedNames() -> [String] {
	var names: [String] = []
	names.reserveCapacity(300)
	for i in 0..<150 {
		names.append("Feed \(i)")
	}
	let longPrefix = "An overly descriptive feed title with lots of padding text to ensure it exceeds the maximum limit for feed-name truncation testing purposes"
	for i in 0..<100 {
		names.append("\(longPrefix) part \(i)")
	}
	for i in 0..<50 {
		names.append("Émojis 🎉🎊🎈 and accénts résumé café feed #\(i)")
	}
	return names
}
