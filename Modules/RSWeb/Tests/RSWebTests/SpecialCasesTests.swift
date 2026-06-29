//
//  SpecialCasesTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 6/27/26.
//

import Testing
import Foundation
@testable import RSWeb

struct SpecialCasesTests {

	@Test func isRedditURLMatchesSubdomains() {
		#expect(URL(string: "https://www.reddit.com/r/swift/.rss")!.isRedditURL)
		#expect(URL(string: "https://old.reddit.com/r/swift/.rss")!.isRedditURL)
		#expect(URL(string: "https://np.reddit.com/r/swift/.rss")!.isRedditURL)
		#expect(URL(string: "https://reddit.com/r/swift/.rss")!.isRedditURL)
	}

	@Test func isRedditURLRejectsLookalikes() {
		#expect(!URL(string: "https://notreddit.com/feed")!.isRedditURL)
		#expect(!URL(string: "https://reddit.com.evil.example/feed")!.isRedditURL)
		#expect(!URL(string: "https://example.com/r/reddit.com")!.isRedditURL)
	}
}
