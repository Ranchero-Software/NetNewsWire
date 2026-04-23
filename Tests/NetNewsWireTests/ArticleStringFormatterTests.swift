//
//  ArticleStringFormatterTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 4/21/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Articles
import Foundation
import Testing

@testable import NetNewsWire

@MainActor @Suite struct ArticleStringFormatterTests {

	// MARK: - truncatedTitle

	@Test func truncatedTitlePlain() {
		let article = makeArticle(title: "Hello World")
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedTitle(article) == "Hello World")
	}

	@Test("Control chars replace with spaces (so words don't fuse), then `collapsingWhitespace` squashes doubles")
	func truncatedTitleReplacesControlCharactersWithSpaces() {
		let article = makeArticle(title: "\rHello\nWorld\twith\r\t\rbreaks\n\t\r\r")
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedTitle(article) == "Hello World with breaks")
	}

	@Test func truncatedTitleDecodesEntitiesWhenNotForHTML() {
		let article = makeArticle(title: "Tom &amp; Jerry")
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedTitle(article, forHTML: false) == "Tom & Jerry")
	}

	@Test func truncatedTitleKeepsEntitiesWhenForHTML() {
		let article = makeArticle(title: "Tom &amp; Jerry")
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedTitle(article, forHTML: true) == "Tom &amp; Jerry")
	}

	@Test func truncatedTitleEmptyForNilTitle() {
		let article = makeArticle(title: nil)
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedTitle(article) == "")
	}

	@Test func truncatedTitleCachedResultIsStable() {
		let article = makeArticle(title: "Repeated Title")
		let formatter = ArticleStringFormatter()
		let first = formatter.truncatedTitle(article)
		let second = formatter.truncatedTitle(article)
		#expect(first == second)
	}

	// MARK: - forHTML collision regression

	// Regression test for a bug in the pre-optimization cache.
	//
	// Old behavior: the cache was keyed by the *sanitized* title. For an
	// article whose title contained entities but no HTML tags (like
	// "Tom &amp; Jerry"), `sanitizedTitle(forHTML: true)` and
	// `sanitizedTitle(forHTML: false)` produced the same sanitized
	// string (the cache key) — but the two paths produce different
	// *output* values: forHTML:false decodes `&amp;` to `&`, forHTML:true
	// preserves it. Whichever call happened first cached its variant and
	// the other caller got the wrong string.
	//
	// New behavior: the cache key includes `forHTML`, so the two calls
	// never collide. This test verifies the fix by calling both in the
	// order that used to expose the bug.
	@Test func forHTMLCollisionRegression() {
		let article = makeArticle(title: "Tom &amp; Jerry")
		let formatter = ArticleStringFormatter()

		// Populate the plain-text cache first.
		let plain = formatter.truncatedTitle(article, forHTML: false)
		#expect(plain == "Tom & Jerry")

		// Now ask for the HTML version — must not return the cached
		// plain-text result.
		let html = formatter.truncatedTitle(article, forHTML: true)
		#expect(html == "Tom &amp; Jerry")
	}

	@Test("Same as the collision test, but populating the HTML cache first")
	func forHTMLCollisionRegressionReverseOrder() {
		let article = makeArticle(title: "Tom &amp; Jerry")
		let formatter = ArticleStringFormatter()

		let html = formatter.truncatedTitle(article, forHTML: true)
		#expect(html == "Tom &amp; Jerry")

		let plain = formatter.truncatedTitle(article, forHTML: false)
		#expect(plain == "Tom & Jerry")
	}

	// MARK: - attributedTruncatedTitle

	@Test func attributedTruncatedTitleNonEmpty() {
		let article = makeArticle(title: "Some Title")
		let formatter = ArticleStringFormatter()
		let attributed = formatter.attributedTruncatedTitle(article)
		#expect(attributed.string == "Some Title")
	}

	@Test func attributedTruncatedTitleEmptyForNilTitle() {
		let article = makeArticle(title: nil)
		let formatter = ArticleStringFormatter()
		let attributed = formatter.attributedTruncatedTitle(article)
		#expect(attributed.string == "")
	}

	@Test("Warm-cache hits must return the same instance — callers mutate only via mutableCopy()")
	func attributedTruncatedTitleReturnsCachedInstance() {
		let article = makeArticle(title: "Cached")
		let formatter = ArticleStringFormatter()
		let first = formatter.attributedTruncatedTitle(article)
		let second = formatter.attributedTruncatedTitle(article)
		#expect(first === second)
	}

	// MARK: - truncatedSummary

	@Test func truncatedSummaryFromContentHTML() {
		let article = makeArticle(title: "T", contentHTML: "<p>Hello <b>World</b></p>")
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedSummary(article) == "Hello World")
	}

	@Test func truncatedSummaryEmptyForNoBody() {
		let article = makeArticle(title: "T", contentHTML: nil)
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedSummary(article) == "")
	}

	@Test("Strip output of \"Comments\" is special-cased to empty for Hacker News")
	func truncatedSummaryHackerNewsCommentsBecomesEmpty() {
		let article = makeArticle(title: "T", contentHTML: "Comments")
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedSummary(article) == "")
	}

	// Regression test for the decode/strip order swap.
	//
	// When an HTML author writes `&lt;i&gt;` in their article body,
	// they mean the *literal text* "<i>" should appear in the
	// rendered output — not a real italic tag. The previous
	// decode-then-strip order would decode `&lt;i&gt;` to `<i>` and
	// then strip it as if it were a tag, making the content
	// disappear. The new strip-then-decode order preserves author
	// intent.
	@Test func summarySemanticsForEntityEncodedLiteralTags() {
		let article = makeArticle(
			title: "T",
			contentHTML: "<p>Use &lt;i&gt; for italics.</p>"
		)
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedSummary(article) == "Use <i> for italics.")
	}

	@Test("Real HTML tags and standalone entities — both old and new orders produce the same output here")
	func summarySemanticsForTypicalHTML() {
		let article = makeArticle(
			title: "T",
			contentHTML: "<p>Tom &amp; Jerry</p>"
		)
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedSummary(article) == "Tom & Jerry")
	}

	// MARK: - dateString

	// `dateString` is intentionally uncached — a real-DB analysis
	// showed 97% of dates are unique at per-second precision, making
	// a cache a net regression. Just verify it returns a non-empty
	// result and picks the time-format branch for today's dates.
	@Test func dateStringTodayReturnsTimeString() {
		let formatter = ArticleStringFormatter()
		let now = Date()
		let result = formatter.dateString(now)
		#expect(!result.isEmpty)
		// Time string won't contain the year; date string would.
		let year = String(Calendar.current.component(.year, from: now))
		#expect(!result.contains(year))
	}

	@Test("Locale-independent smoke test: past date formats through the `.medium` date formatter")
	func dateStringPastReturnsNonEmpty() {
		let formatter = ArticleStringFormatter()
		let longAgo = Date(timeIntervalSince1970: 0) // 1970-01-01
		#expect(!formatter.dateString(longAgo).isEmpty)
	}

	// MARK: - truncatedFeedName

	@Test func truncatedFeedNameShortPassesThrough() {
		let formatter = ArticleStringFormatter()
		#expect(formatter.truncatedFeedName("Daring Fireball") == "Daring Fireball")
	}

	@Test func truncatedFeedNameLongIsTruncated() {
		let formatter = ArticleStringFormatter()
		let feedName = String(repeating: "x", count: 200)
		#expect(formatter.truncatedFeedName(feedName).count == 100)
	}
}

// MARK: - Helpers

@MainActor private func makeArticle(
	articleID: String = "article1",
	accountID: String = "account1",
	title: String? = "Untitled",
	contentHTML: String? = nil
) -> Article {
	let status = ArticleStatus(articleID: articleID, read: false, starred: false, dateArrived: Date())
	return Article(
		accountID: accountID,
		articleID: articleID,
		feedID: "feed1",
		uniqueID: "unique-\(articleID)",
		title: title,
		contentHTML: contentHTML,
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
}
