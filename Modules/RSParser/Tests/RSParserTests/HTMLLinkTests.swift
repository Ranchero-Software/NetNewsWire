//
//  HTMLLinkTests.swift
//  RSParser
//
//  Created by Brent Simmons on 6/25/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
import RSParser
import RSParserObjC

@Suite struct HTMLLinkTests {

	@Test func sixColorsLink() {
		let d = parserData("sixcolors", "html", "http://sixcolors.com/")
		let links = HTMLLinkParser.htmlLinks(with: d)

		let linkToFind = "https://www.theincomparable.com/theincomparable/290/index.php"
		let textToFind = "this week’s episode of The Incomparable"

		var found = false
		for oneLink in links {
			if let urlString = oneLink.urlString, let text = oneLink.text, urlString == linkToFind, text == textToFind {
				found = true
			}
		}

		#expect(found)
		#expect(links.count == 131)
	}

	// MARK: - Inline fixture tests

	@Test func linksInsideScriptAreIgnored() {
		// The scanner enters raw-text mode for <script> — `<a href>` inside JS
		// string literals must not be picked up. Test content has to look enough
		// like markup to trip a naive scanner.
		let html = """
		<html><body>
		<a href="http://real.example.com/">real</a>
		<script>
		  var markup = '<a href="http://not-a-link.example.com/">nope</a>';
		  var also = "<a href='http://also-not.example.com/'>also nope</a>";
		</script>
		<a href="http://real2.example.com/">real 2</a>
		</body></html>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let links = HTMLLinkParser.htmlLinks(with: d)
		let urls = links.compactMap { $0.urlString }
		#expect(urls.contains("http://real.example.com/"))
		#expect(urls.contains("http://real2.example.com/"))
		#expect(!urls.contains("http://not-a-link.example.com/"))
		#expect(!urls.contains("http://also-not.example.com/"))
	}

	@Test func linksInsideStyleAreIgnored() {
		// <style> is also raw-text. Background-image URL inside CSS must not
		// be picked up as a link.
		let html = """
		<html><body>
		<style>
		  .banner { background: url('http://css-url.example.com/bg.png'); }
		  /* <a href="http://commented-out.example.com/">x</a> */
		</style>
		<a href="http://real.example.com/">real</a>
		</body></html>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let links = HTMLLinkParser.htmlLinks(with: d)
		let urls = links.compactMap { $0.urlString }
		#expect(urls == ["http://real.example.com/"])
	}

	@Test func relativeURLsResolvedAgainstPageURL() {
		// The parser's second argument is the page URL; relative hrefs must
		// resolve against it so the caller gets absolute URLs back.
		let html = """
		<html><body>
		  <a href="/foo">absolute path</a>
		  <a href="bar.html">relative path</a>
		  <a href="http://other.example.com/x">already absolute</a>
		</body></html>
		"""
		let d = ParserData(url: "http://example.com/page/", data: Data(html.utf8))
		let links = HTMLLinkParser.htmlLinks(with: d)
		let urls = links.compactMap { $0.urlString }
		#expect(urls.contains("http://example.com/foo"))
		#expect(urls.contains("http://example.com/page/bar.html"))
		#expect(urls.contains("http://other.example.com/x"))
	}

	@Test func unclosedTagsDoNotCrashAndStillFindLinks() {
		// Malformed markup: the scanner must not hang or lose later links.
		let html = """
		<html><body>
		<p>Orphan <b>bold <i>italic
		<a href="http://example.com/first">first</a>
		<div>Unclosed div
		<a href="http://example.com/second">second</a>
		</body>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let links = HTMLLinkParser.htmlLinks(with: d)
		let urls = links.compactMap { $0.urlString }
		#expect(urls.contains("http://example.com/first"))
		#expect(urls.contains("http://example.com/second"))
	}

	@Test func anchorWithoutHrefIgnored() {
		// `<a>` without href is an anchor target, not a link. Must not appear.
		let html = """
		<html><body>
		<a name="top"></a>
		<a href="http://example.com/">real</a>
		<a>no href at all</a>
		</body></html>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let links = HTMLLinkParser.htmlLinks(with: d)
		let urls = links.compactMap { $0.urlString }
		#expect(urls == ["http://example.com/"])
	}

	@Test func entitiesInHrefDecoded() {
		// href attribute values routinely contain `&amp;` as a query-parameter
		// separator. After extraction the caller expects the decoded `&` (so
		// the URL they get is the real URL, not the HTML-escaped spelling).
		// A regression that stopped decoding entities in attribute values
		// would silently break every URL with a `?a=1&b=2`-style query.
		let html = """
		<html><body>
		<a href="http://example.com/search?q=foo&amp;page=2">two-param</a>
		<a href="http://example.com/a?x=1&amp;y=2&amp;z=3">three-param</a>
		</body></html>
		"""
		let d = ParserData(url: "http://example.com/", data: Data(html.utf8))
		let links = HTMLLinkParser.htmlLinks(with: d)
		let urls = links.compactMap { $0.urlString }
		#expect(urls.contains("http://example.com/search?q=foo&page=2"))
		#expect(urls.contains("http://example.com/a?x=1&y=2&z=3"))
		// No `&amp;` should leak through.
		for u in urls {
			#expect(!u.contains("&amp;"), "entity not decoded in href: \(u)")
		}
	}
}
