//
//  ArticleRenderingSpecialCasesTests.swift
//  NetNewsWireTests
//
//  Created by Brent Simmons on 2026-07-06.
//

import Foundation
import Testing

@testable import NetNewsWire

@Suite struct ArticleRenderingSpecialCasesTests {

	// <https://github.com/Ranchero-Software/NetNewsWire/issues/4150>

	@Test func redirectAssignmentIsRemoved() {
		let html = "<p>Before</p><script>location.href='https://example.com/full/';</script><p>After</p>"
		let filtered = ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/post/", html: html)
		#expect(!filtered.contains("location.href"))
		#expect(filtered.contains("<p>Before</p>"))
		#expect(filtered.contains("<p>After</p>"))
	}

	@Test func spacedAssignmentAndWindowLocationRemoved() {
		let html = "<script> window.location.href = 'https://example.com/x/' ;</script>KEEP"
		let filtered = ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: html)
		#expect(!filtered.contains("location.href"))
		#expect(filtered.contains("KEEP"))
	}

	// A read/comparison of location.href is not an assignment — keep it.
	@Test func readsAndComparisonsAreKept() {
		let read = "<script>if (location.href.includes('x')) { doThing(); }</script>"
		let compare = "<script>if (location.href == 'x') { doThing(); }</script>"
		#expect(ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: read) == read)
		#expect(ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: compare) == compare)
	}

	// Fast path: no mention of location.href → returned unchanged.
	@Test func contentWithoutLocationHrefIsUnchanged() {
		let html = "<p>Just an article.</p><script>console.log('hi');</script>"
		#expect(ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: "https://example.com/a/", html: html) == html)
	}

	// MARK: - JavaScript disabled by domain

	@Test func slashdotSubdomainLinkDisablesJavaScript() {
		let link = "https://yro.slashdot.org/story/26/09/18/0023251/will-california-gut-its-net-neutrality-law?utm_source=rss1.0mainlinkanon&utm_medium=feed"
		#expect(ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: [link, nil, nil]))
	}

	@Test func slashdotRootLinkDisablesJavaScript() {
		#expect(ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: ["https://slashdot.org/", nil, nil]))
	}

	@Test func slashdotFeedURLDisablesJavaScriptWhenLinkIsNil() {
		#expect(ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: [nil, "https://rss.slashdot.org/Slashdot/slashdotMain", nil]))
	}

	@Test func otherDomainKeepsJavaScript() {
		#expect(!ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: ["https://example.com/post/", "https://example.com/feed.xml", "https://example.com/"]))
	}

	// The domain must match at a subdomain boundary, not as a bare suffix.
	@Test func similarDomainKeepsJavaScript() {
		#expect(!ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: ["https://notslashdot.org/story/", nil, nil]))
	}

	@Test func allNilURLsKeepJavaScript() {
		#expect(!ArticleRenderingSpecialCases.shouldDisableJavaScript(urlStrings: [nil, nil, nil]))
	}
}
