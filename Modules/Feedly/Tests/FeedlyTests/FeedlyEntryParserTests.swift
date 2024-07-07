//
//  FeedlyEntryParserTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 29/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Feedly

final class FeedlyEntryParserTests: XCTestCase {

	func testParsing() {
		let content = FeedlyEntry.Content(content: "Test Content", direction: .leftToRight)
		let summary = FeedlyEntry.Content(content: "Test Summary", direction: .leftToRight)
		let origin = FeedlyOrigin(title: "Test Feed", streamID: "tests://feeds/1", htmlURL: nil)
		let canonicalLink = FeedlyLink(href: "tests://feeds/1/entries/1", type: "text/html")
		let tags = [
			FeedlyTag(id: "tests/tags/1", label: "Tag 1"),
			FeedlyTag(id: "tests/tags/2", label: "Tag 2")
		]
		let entry = FeedlyEntry(id: "tests/feeds/1/entries/1",
								title: "Test Entry 1",
								content: content,
								summary: summary,
								author: "Bob Alice",
								crawled: .distantPast,
								recrawled: Date(timeIntervalSinceReferenceDate: 0),
								origin: origin,
								canonical: [canonicalLink],
								alternate: nil,
								unread: false,
								tags: tags,
								categories: nil,
								enclosure: nil)
		
		let parser = FeedlyEntryParser(entry: entry)
		
		XCTAssertEqual(parser.id, entry.id)
		XCTAssertEqual(parser.feedUrl, origin.streamID)
		XCTAssertEqual(parser.externalUrl, canonicalLink.href)
		XCTAssertEqual(parser.title, entry.title)
		XCTAssertEqual(parser.contentHMTL, content.content)
		XCTAssertEqual(parser.summary, summary.content)
		XCTAssertEqual(parser.datePublished, Date.distantPast)
		XCTAssertEqual(parser.dateModified, Date(timeIntervalSinceReferenceDate: 0))
		
		guard let item = parser.parsedItemRepresentation else {
			XCTFail("Expected a parsed item representation.")
			return
		}
		
		XCTAssertEqual(item.syncServiceID, entry.id)
		XCTAssertEqual(item.uniqueID, entry.id)
		
		// The following is not an error.
		// The feedURL must match the feedID for the article to be connected to its matching feed.
		XCTAssertEqual(item.feedURL, origin.streamID)
		XCTAssertEqual(item.title, entry.title)
		XCTAssertEqual(item.contentHTML, content.content)
		XCTAssertEqual(item.contentText, nil, "Is it now free of HTML characters?")
		XCTAssertEqual(item.summary, summary.content)
		XCTAssertEqual(item.datePublished, entry.crawled)
		XCTAssertEqual(item.dateModified, entry.recrawled)
		
		let expectedTags = Set(tags.compactMap { $0.label })
		XCTAssertEqual(item.tags, expectedTags)
		
		let expectedAuthors = Set([entry.author])
		let calculatedAuthors = Set(item.authors?.compactMap { $0.name } ?? [])
		XCTAssertEqual(calculatedAuthors, expectedAuthors)
	}
	
	func testSanitization() {
		let content = FeedlyEntry.Content(content: "<div style=\"direction:rtl;text-align:right\">Test Content</div>", direction: .rightToLeft)
		let summaryContent = "Test Summary"
		let summary = FeedlyEntry.Content(content: "<div style=\"direction:rtl;text-align:right\">\(summaryContent)</div>", direction: .rightToLeft)
		let origin = FeedlyOrigin(title: "Test Feed", streamID: "tests://feeds/1", htmlURL: nil)
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
	
	func testContentPreferredToSummary() {
		let content = FeedlyEntry.Content(content: "Test Content", direction: .leftToRight)
		let summary = FeedlyEntry.Content(content: "Test Summary", direction: .leftToRight)
		let entry = FeedlyEntry(id: "tests/feeds/1/entries/1",
								title: "Test Entry 1",
								content: content,
								summary: summary,
								author: nil,
								crawled: .distantPast,
								recrawled: Date(timeIntervalSinceReferenceDate: 0),
								origin: nil,
								canonical: nil,
								alternate: nil,
								unread: false,
								tags: nil,
								categories: nil,
								enclosure: nil)
		
		let parser = FeedlyEntryParser(entry: entry)
		
		XCTAssertEqual(parser.contentHMTL, content.content)
	}
	
	func testSummaryUsedAsContentWhenContentMissing() {
		let summary = FeedlyEntry.Content(content: "Test Summary", direction: .leftToRight)
		let entry = FeedlyEntry(id: "tests/feeds/1/entries/1",
								title: "Test Entry 1",
								content: nil,
								summary: summary,
								author: nil,
								crawled: .distantPast,
								recrawled: Date(timeIntervalSinceReferenceDate: 0),
								origin: nil,
								canonical: nil,
								alternate: nil,
								unread: false,
								tags: nil,
								categories: nil,
								enclosure: nil)
		
		let parser = FeedlyEntryParser(entry: entry)
		
		XCTAssertEqual(parser.contentHMTL, summary.content)
	}
}
