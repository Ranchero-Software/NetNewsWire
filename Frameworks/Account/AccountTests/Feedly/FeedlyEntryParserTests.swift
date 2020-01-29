//
//  FeedlyEntryParserTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 29/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class FeedlyEntryParserTests: XCTestCase {
	
	func testParsing() {
		let content = FeedlyEntry.Content(content: "Test Content", direction: .leftToRight)
		let summary = FeedlyEntry.Content(content: "Test Summary", direction: .leftToRight)
		let origin = FeedlyOrigin(title: "Test Feed", streamId: "tests://feeds/1", htmlUrl: nil)
		let entry = FeedlyEntry(id: "tests/feeds/1/entries/1",
								title: "Test Entry 1",
								content: content,
								summary: summary,
								author: nil,
								crawled: .distantPast,
								recrawled: Date(timeIntervalSinceReferenceDate: 0),
								origin: origin,
								canonical: nil,
								alternate: nil,
								unread: false,
								tags: nil,
								categories: nil,
								enclosure: nil)
		
		let parser = FeedlyEntryParser(entry: entry)
		
		XCTAssertEqual(parser.id, entry.id)
		XCTAssertEqual(parser.feedUrl, origin.streamId)
		XCTAssertEqual(parser.externalUrl, nil)
		XCTAssertEqual(parser.title, entry.title)
		XCTAssertEqual(parser.contentHMTL, content.content)
		XCTAssertEqual(parser.summary, summary.content)
		XCTAssertEqual(parser.datePublished, .distantPast)
		XCTAssertEqual(parser.dateModified, Date(timeIntervalSinceReferenceDate: 0))
	}
	
	func testSanitization() {
		let content = FeedlyEntry.Content(content: "<div style=\"direction:rtl;text-align:right\">Test Content</div>", direction: .rightToLeft)
		let summaryContent = "Test Summary"
		let summary = FeedlyEntry.Content(content: "<div style=\"direction:rtl;text-align:right\">\(summaryContent)</div>", direction: .rightToLeft)
		let origin = FeedlyOrigin(title: "Test Feed", streamId: "tests://feeds/1", htmlUrl: nil)
		let title = "Test Entry 1"
		let entry = FeedlyEntry(id: "tests/feeds/1/entries/1",
								title: "<div style=\"direction:rtl;text-align:right\">\(title)</div>",
								content: content,
								summary: summary,
								author: nil,
								crawled: .distantPast,
								recrawled: nil,
								origin: origin,
								canonical: nil,
								alternate: nil,
								unread: false,
								tags: nil,
								categories: nil,
								enclosure: nil)
		
		let parser = FeedlyEntryParser(entry: entry)
		
		// These should be sanitized
		XCTAssertEqual(parser.title, title)
		XCTAssertEqual(parser.summary, summaryContent)
		
		// These should not be sanitized because it is supposed to be HTML content.
		XCTAssertEqual(parser.contentHMTL, content.content)
	}
	
	func testLocatesCanonicalExternalUrl() {
		let canonicalLink = FeedlyLink(href: "tests://feeds/1/entries/1", type: "text/html")
		let alternateLink = FeedlyLink(href: "tests://feeds/1/entries/alternate/1", type: "text/html")
		let entry = FeedlyEntry(id: "tests/feeds/1/entries/1",
								title: "Test Entry 1",
								content: nil,
								summary: nil,
								author: nil,
								crawled: .distantPast,
								recrawled: Date(timeIntervalSinceReferenceDate: 0),
								origin: nil,
								canonical: [canonicalLink],
								alternate: [alternateLink],
								unread: false,
								tags: nil,
								categories: nil,
								enclosure: nil)
		
		let parser = FeedlyEntryParser(entry: entry)
		
		XCTAssertEqual(parser.externalUrl, canonicalLink.href)
	}
	
	func testLocatesAlternateExternalUrl() {
		let canonicalLink = FeedlyLink(href: "tests://feeds/1/entries/1", type: "text/json")
		let alternateLink = FeedlyLink(href: "tests://feeds/1/entries/alternate/1", type: nil)
		let entry = FeedlyEntry(id: "tests/feeds/1/entries/1",
								title: "Test Entry 1",
								content: nil,
								summary: nil,
								author: nil,
								crawled: .distantPast,
								recrawled: Date(timeIntervalSinceReferenceDate: 0),
								origin: nil,
								canonical: [canonicalLink],
								alternate: [alternateLink],
								unread: false,
								tags: nil,
								categories: nil,
								enclosure: nil)
		
		let parser = FeedlyEntryParser(entry: entry)
		
		XCTAssertEqual(parser.externalUrl, alternateLink.href)
	}
}
