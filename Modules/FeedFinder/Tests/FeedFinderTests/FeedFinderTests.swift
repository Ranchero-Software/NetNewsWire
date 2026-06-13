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

	// Covers #5299: a page-specific feed linked in the body (e.g. /blog/feed)
	// must be recognized as "under" the requested page path so it can be
	// preferred over a site-wide <head> feed.
	func testFeedURLIsUnderRequestedPagePath() {
		func isUnder(_ feed: String, _ page: String) -> Bool {
			FeedFinder.feedURLString(feed, isUnderRequestedPageURLString: page)
		}

		// The bug case: /blog/feed is under the requested /blog page…
		XCTAssertTrue(isUnder("https://www.relay.fm/blog/feed", "https://www.relay.fm/blog"))
		// …while the site-wide feed at a different path is not on-path.
		XCTAssertFalse(isUnder("http://relay.fm/master/feed", "https://www.relay.fm/blog"))

		// Host comparison is www- and case-insensitive.
		XCTAssertTrue(isUnder("https://relay.fm/blog/feed", "https://www.relay.fm/blog"))
		XCTAssertTrue(isUnder("https://WWW.Relay.FM/blog/feed", "https://www.relay.fm/blog"))

		// A different host is never on-path.
		XCTAssertFalse(isUnder("https://example.com/blog/feed", "https://www.relay.fm/blog"))

		// A root request gets no on-path preference (whole-site Find Feed unchanged).
		XCTAssertFalse(isUnder("https://relay.fm/feed", "https://relay.fm/"))
		XCTAssertFalse(isUnder("https://relay.fm/feed", "https://relay.fm"))

		// A sibling that merely shares a path prefix is not nested under it.
		XCTAssertFalse(isUnder("https://relay.fm/blogger/feed", "https://relay.fm/blog"))

		// An exact path match counts as on-path.
		XCTAssertTrue(isUnder("https://relay.fm/blog", "https://relay.fm/blog"))
	}
}
