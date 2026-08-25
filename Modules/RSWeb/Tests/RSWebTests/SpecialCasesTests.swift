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

	@Test func isRelayFMBlogURLMatchesBlog() {
		#expect(URL(string: "https://www.relay.fm/blog")!.isRelayFMBlogURL)
		#expect(URL(string: "http://relay.fm/blog")!.isRelayFMBlogURL)
		#expect(URL(string: "https://www.relay.fm/blog/")!.isRelayFMBlogURL)
		#expect(URL(string: "https://www.relay.fm/blog/some-post")!.isRelayFMBlogURL)
	}

	@Test func isRelayFMBlogURLRejectsNonBlog() {
		#expect(!URL(string: "https://relay.fm")!.isRelayFMBlogURL)          // root → master feed
		#expect(!URL(string: "http://relay.fm/master/feed")!.isRelayFMBlogURL)
		#expect(!URL(string: "https://www.relay.fm/blogsomething")!.isRelayFMBlogURL)
		#expect(!URL(string: "https://relay.fm.evil.example/blog")!.isRelayFMBlogURL) // host check
	}
}
