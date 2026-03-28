//
//  ArticleFilterTests.swift
//  AccountTests
//
//  Created on 3/23/26.
//

import XCTest
import Articles
@testable import Account

@MainActor final class ArticleFilterTests: XCTestCase {

	// MARK: - Contains Match Type

	func testContainsMatchesTitleKeyword() {
		let filter = ArticleFilter(keyword: "space", matchType: .contains)
		let article = makeArticle(title: "SpaceX launches new rocket")
		XCTAssertTrue(filter.matches(article))
	}

	func testContainsDoesNotMatchWhenKeywordAbsent() {
		let filter = ArticleFilter(keyword: "space", matchType: .contains)
		let article = makeArticle(title: "New iPhone released")
		XCTAssertFalse(filter.matches(article))
	}

	func testContainsMatchesContentHTML() {
		let filter = ArticleFilter(keyword: "podcast", matchType: .contains)
		let article = makeArticle(title: "Weekly Update", contentHTML: "<p>Listen to our podcast episode</p>")
		XCTAssertTrue(filter.matches(article))
	}

	func testContainsMatchesSummary() {
		let filter = ArticleFilter(keyword: "rocketry", matchType: .contains)
		let article = makeArticle(title: "Science News", summary: "Today in rocketry and beyond")
		XCTAssertTrue(filter.matches(article))
	}

	func testContainsMatchesContentText() {
		let filter = ArticleFilter(keyword: "rocketry", matchType: .contains)
		let article = makeArticle(title: "Science News", contentText: "Latest advances in rocketry and space travel")
		XCTAssertTrue(filter.matches(article))
	}

	func testContainsPrefersContentTextOverHTML() {
		let filter = ArticleFilter(keyword: "strong", matchType: .contains)
		let article = makeArticle(title: "News", contentHTML: "<strong>Bold text</strong>", contentText: "Bold text")
		XCTAssertFalse(filter.matches(article), "Should not match HTML tags when contentText is available")
	}

	func testContainsFallsBackToContentHTMLWhenNoContentText() {
		let filter = ArticleFilter(keyword: "breaking", matchType: .contains)
		let article = makeArticle(title: "News", contentHTML: "<p>Breaking news today</p>")
		XCTAssertTrue(filter.matches(article))
	}

	func testContainsMatchesAuthorName() throws {
		let filter = ArticleFilter(keyword: "johndoe", matchType: .contains)
		let author = try XCTUnwrap(Author(authorID: nil, name: "JohnDoe", url: nil, avatarURL: nil, emailAddress: nil))
		let article = makeArticle(title: "Some Article", authors: Set([author]))
		XCTAssertTrue(filter.matches(article))
	}

	// MARK: - DoesNotContain Match Type

	func testDoesNotContainMarksReadWhenKeywordAbsent() {
		let filter = ArticleFilter(keyword: "AI", matchType: .doesNotContain)
		let article = makeArticle(title: "New cooking recipes")
		XCTAssertTrue(filter.matches(article), "Should match (mark as read) when keyword is absent")
	}

	func testDoesNotContainDoesNotMatchWhenKeywordPresent() {
		let filter = ArticleFilter(keyword: "AI", matchType: .doesNotContain)
		let article = makeArticle(title: "AI breakthroughs in 2026")
		XCTAssertFalse(filter.matches(article), "Should not match when keyword is present")
	}

	// MARK: - Case Insensitivity

	func testMatchingIsCaseInsensitive() {
		let filter = ArticleFilter(keyword: "SPACE", matchType: .contains)
		let article = makeArticle(title: "space exploration continues")
		XCTAssertTrue(filter.matches(article))
	}

	func testMatchingIsCaseInsensitiveReverse() {
		let filter = ArticleFilter(keyword: "space", matchType: .contains)
		let article = makeArticle(title: "SPACE exploration continues")
		XCTAssertTrue(filter.matches(article))
	}

	// MARK: - Edge Cases

	func testEmptyKeywordNeverMatches() {
		let filter = ArticleFilter(keyword: "", matchType: .contains)
		let article = makeArticle(title: "Anything")
		XCTAssertFalse(filter.matches(article))
	}

	func testWhitespaceOnlyKeywordNeverMatches() {
		let filter = ArticleFilter(keyword: "   ", matchType: .contains)
		let article = makeArticle(title: "Anything")
		XCTAssertFalse(filter.matches(article))
	}

	func testEmptyKeywordDoesNotContainNeverMatches() {
		let filter = ArticleFilter(keyword: "", matchType: .doesNotContain)
		let article = makeArticle(title: "Anything")
		XCTAssertFalse(filter.matches(article))
	}

	// MARK: - Multiple Filters (anyFilterMatches)

	func testAnyFilterMatchesReturnsTrueWhenOneMatches() {
		let filters: [ArticleFilter] = [
			ArticleFilter(keyword: "space", matchType: .contains),
			ArticleFilter(keyword: "cooking", matchType: .contains)
		]
		let article = makeArticle(title: "Space news today")
		XCTAssertTrue(filters.anyFilterMatches(article))
	}

	func testAnyFilterMatchesReturnsFalseWhenNoneMatch() {
		let filters: [ArticleFilter] = [
			ArticleFilter(keyword: "space", matchType: .contains),
			ArticleFilter(keyword: "cooking", matchType: .contains)
		]
		let article = makeArticle(title: "Politics update")
		XCTAssertFalse(filters.anyFilterMatches(article))
	}

	func testEmptyFiltersArrayNeverMatches() {
		let filters: [ArticleFilter] = []
		let article = makeArticle(title: "Anything at all")
		XCTAssertFalse(filters.anyFilterMatches(article))
	}

	// MARK: - Tag Matching

	func testContainsMatchesTag() {
		let filter = ArticleFilter(keyword: "AI", matchType: .contains)
		let article = makeArticle(title: "Some generic article")
		let tags: Set<String> = ["AI", "Technology"]
		XCTAssertTrue(filter.matches(article, tags: tags))
	}

	func testContainsMatchesTagCaseInsensitive() {
		let filter = ArticleFilter(keyword: "space", matchType: .contains)
		let article = makeArticle(title: "Science update")
		let tags: Set<String> = ["Space", "Astronomy"]
		XCTAssertTrue(filter.matches(article, tags: tags))
	}

	func testDoesNotContainChecksTagsToo() {
		let filter = ArticleFilter(keyword: "AI", matchType: .doesNotContain)
		let article = makeArticle(title: "Some generic article")
		let tags: Set<String> = ["AI", "Technology"]
		XCTAssertFalse(filter.matches(article, tags: tags), "Should not match (mark as read) when keyword is in tags")
	}

	func testContainsDoesNotMatchWhenTagAbsent() {
		let filter = ArticleFilter(keyword: "sports", matchType: .contains)
		let article = makeArticle(title: "Tech news")
		let tags: Set<String> = ["AI", "Technology"]
		XCTAssertFalse(filter.matches(article, tags: tags))
	}

	func testNilTagsFallsBackToArticleText() {
		let filter = ArticleFilter(keyword: "rocket", matchType: .contains)
		let article = makeArticle(title: "Rocket launch today")
		XCTAssertTrue(filter.matches(article, tags: nil))
	}

	// MARK: - Match Fields

	func testMatchFieldsTagOnly() {
		let filter = ArticleFilter(keyword: "AI", matchType: .contains, matchFields: .tag)
		let article = makeArticle(title: "AI news today")
		XCTAssertFalse(filter.matches(article), "Should not match title when matchFields is tag-only")
		XCTAssertTrue(filter.matches(article, tags: ["AI"]))
	}

	func testMatchFieldsTitleOnly() {
		let filter = ArticleFilter(keyword: "AI", matchType: .contains, matchFields: .title)
		let article = makeArticle(title: "AI news today")
		XCTAssertTrue(filter.matches(article))
		XCTAssertTrue(filter.matches(article, tags: []), "Title match should succeed even with empty tags")
	}

	func testMatchFieldsTitleOnlyIgnoresTags() {
		let filter = ArticleFilter(keyword: "sports", matchType: .contains, matchFields: .title)
		let article = makeArticle(title: "Tech news")
		XCTAssertFalse(filter.matches(article, tags: ["sports"]), "Should not match tags when matchFields is title-only")
	}

	func testMatchFieldsContentOnly() {
		let filter = ArticleFilter(keyword: "breaking", matchType: .contains, matchFields: .content)
		let article = makeArticle(title: "News", contentText: "Breaking news today")
		XCTAssertTrue(filter.matches(article))
	}

	func testMatchFieldsContentOnlyIgnoresTitle() {
		let filter = ArticleFilter(keyword: "News", matchType: .contains, matchFields: .content)
		let article = makeArticle(title: "News", contentText: "Hello world")
		XCTAssertFalse(filter.matches(article))
	}

	func testMatchFieldsNilDefaultsToAll() {
		let filter = ArticleFilter(keyword: "AI", matchType: .contains, matchFields: nil)
		let article = makeArticle(title: "AI news")
		XCTAssertTrue(filter.matches(article))
		let article2 = makeArticle(title: "Other")
		XCTAssertTrue(filter.matches(article2, tags: ["AI"]))
	}

	func testMatchFieldsCombined() {
		let filter = ArticleFilter(keyword: "AI", matchType: .contains, matchFields: [.tag, .title])
		let article = makeArticle(title: "Tech news", summary: "AI is everywhere")
		XCTAssertFalse(filter.matches(article), "Should not match summary when matchFields is tag+title")
	}

	// MARK: - JSON Roundtrip

	func testJSONRoundtrip() throws {
		let filters: [ArticleFilter] = [
			ArticleFilter(keyword: "space", matchType: .contains),
			ArticleFilter(keyword: "AI", matchType: .doesNotContain)
		]

		let json = try XCTUnwrap(filters.json())
		let decoded = [ArticleFilter].filtersWithJSON(json)
		XCTAssertEqual(decoded, filters)
	}

	// MARK: - Helpers

	private func makeArticle(
		title: String? = nil,
		contentHTML: String? = nil,
		contentText: String? = nil,
		summary: String? = nil,
		authors: Set<Author>? = nil
	) -> Article {
		let status = ArticleStatus(articleID: UUID().uuidString, read: false, dateArrived: Date())
		return Article(
			accountID: "test-account",
			articleID: nil,
			feedID: "test-feed",
			uniqueID: UUID().uuidString,
			title: title,
			contentHTML: contentHTML,
			contentText: contentText,
			markdown: nil,
			url: nil,
			externalURL: nil,
			summary: summary,
			imageURL: nil,
			datePublished: nil,
			dateModified: nil,
			authors: authors,
			status: status
		)
	}
}
