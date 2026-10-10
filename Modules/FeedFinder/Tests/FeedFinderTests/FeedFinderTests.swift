//
//  FeedFinderTests.swift
//  FeedFinderTests
//
//  Created by Brent Simmons on 11/9/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import XCTest
@testable import FeedFinder
import RSParser

final class FeedFinderTests: XCTestCase {

	func testExample() throws {
		let feedFinder = FeedFinder()
		XCTAssertNotNil(feedFinder)
	}

	func testKnownFeedSpecifierForRelayFMBlog() throws {
		let specifier = FeedSpecifier.knownFeedSpecifier(url: URL(string: "https://www.relay.fm/blog")!)
		XCTAssertEqual(specifier?.urlString, "https://www.relay.fm/blog/feed")
	}

	func testKnownFeedSpecifierIgnoresRelayFMRoot() throws {
		XCTAssertNil(FeedSpecifier.knownFeedSpecifier(url: URL(string: "https://www.relay.fm")!))
	}

	func testBodyLinksWithNonFeedExtensionsAreIgnored() throws {
		let urlStrings = feedURLStringsInBodyLinks([
			"https://example.com/feed.xml",
			"https://example.com/feed.PDF",
			"https://example.com/feed.pdf?download=1",
			"https://example.com/rss.jpg#top"
		])
		XCTAssertEqual(urlStrings, ["https://example.com/feed.xml"])
	}
}

private extension FeedFinderTests {

	func feedURLStringsInBodyLinks(_ urlStrings: [String]) -> Set<String> {
		let links = urlStrings.map { "<a href=\"\($0)\">Link</a>" }.joined()
		let html = "<html><body>\(links)</body></html>"
		let parserData = ParserData(url: "https://example.com/", data: Data(html.utf8))
		let feedFinder = HTMLFeedFinder(parserData: parserData)
		return Set(feedFinder.feedSpecifiers.map(\.urlString))
	}
}
