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
}
