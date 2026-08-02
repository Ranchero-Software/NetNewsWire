//
//  FeedFinderTests.swift
//  FeedFinderTests
//
//  Created by Brent Simmons on 11/9/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import XCTest
@testable import FeedFinder

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
}
