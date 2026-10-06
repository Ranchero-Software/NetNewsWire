//
//  HTMLRelativeURLResolverTests.swift
//  RSParser
//
//  Created by Brent Simmons on 7/28/26.
//

import Foundation
import Testing
import RSParser

@Suite struct HTMLRelativeURLResolverTests {

	private let base = URL(string: "https://example.com/blog/post1/")!

	private func resolved(_ html: String) -> String {
		HTMLRelativeURLResolver.resolvingRelativeURLs(in: html, baseURL: base)
	}

	// MARK: - Values that resolve

	@Test func relativeValuesResolve() {
		let cases: [(input: String, expected: String)] = [
			("<a href=\"page.html\">x</a>", "<a href=\"https://example.com/blog/post1/page.html\">x</a>"),
			("<img src=\"img.png\">", "<img src=\"https://example.com/blog/post1/img.png\">"),
			("<video poster=\"p.jpg\"></video>", "<video poster=\"https://example.com/blog/post1/p.jpg\"></video>"),
			("<a href=\"/root\">x</a>", "<a href=\"https://example.com/root\">x</a>"),
			("<a href=\"../up/\">x</a>", "<a href=\"https://example.com/blog/up/\">x</a>"),
			("<a href=\"?q=1\">x</a>", "<a href=\"https://example.com/blog/post1/?q=1\">x</a>"),
			("<a href=\"//cdn.example.com/x\">x</a>", "<a href=\"https://cdn.example.com/x\">x</a>")
		]
		for c in cases {
			#expect(resolved(c.input) == c.expected, "mismatch for \(c.input)")
		}
	}

	@Test func ampersandEntityInRelativeURLSurvives() {
		let html = "<a href=\"page?a=1&amp;b=2\">x</a>"
		#expect(resolved(html) == "<a href=\"https://example.com/blog/post1/page?a=1&amp;b=2\">x</a>")
	}

	@Test func attributeNamesAreCaseInsensitive() {
		#expect(resolved("<a HREF=\"x\">y</a>") == "<a HREF=\"https://example.com/blog/post1/x\">y</a>")
		#expect(resolved("<img SrcSet=\"x 1x\">") == "<img SrcSet=\"https://example.com/blog/post1/x 1x\">")
	}

	@Test func unquotedAndSingleQuotedValuesResolve() {
		#expect(resolved("<a href=foo/bar>x</a>") == "<a href=https://example.com/blog/post1/foo/bar>x</a>")
		#expect(resolved("<a href='x'>y</a>") == "<a href='https://example.com/blog/post1/x'>y</a>")
	}

	// MARK: - Values left alone

	@Test func untouchedValues() {
		let cases = [
			"<a href=\"#fn1\">x</a>",
			"<a href=\"\">x</a>",
			"<a href=\"https://other.example.com/a\">x</a>",
			"<a href=\"http://other.example.com/a\">x</a>",
			"<img src=\"data:image/png;base64,AAAA\">",
			"<a href=\"mailto:x@example.com\">x</a>",
			"<a href=\"javascript:void(0)\">x</a>",
			"<a title=\"foo.png\" data-src=\"x\">not URL attributes</a>"
		]
		for html in cases {
			#expect(resolved(html) == html, "expected no change for \(html)")
		}
	}

	@Test func scriptStyleCommentsAndCDATAUntouched() {
		let cases = [
			"<script>var a = \"<img src=foo>\";</script>",
			"<style>.x { background: url(foo.png); }</style>",
			"<!-- <a href=\"x\">commented out</a> -->",
			"<![CDATA[<a href=\"x\">]]>"
		]
		for html in cases {
			#expect(resolved(html) == html, "expected no change for \(html)")
		}
	}

	@Test func scriptSrcAttributeStillResolves() {
		// The script element's own attributes are scanned — only its text content is skipped.
		let html = "<script src=\"app.js\">var s = \"<img src=x>\";</script>"
		#expect(resolved(html) == "<script src=\"https://example.com/blog/post1/app.js\">var s = \"<img src=x>\";</script>")
	}

	// MARK: - srcset

	@Test func srcsetCandidatesResolve() {
		let cases: [(input: String, expected: String)] = [
			("<img srcset=\"a.png\">",
			 "<img srcset=\"https://example.com/blog/post1/a.png\">"),
			("<img srcset=\"a.png 1x, b.png 2x\">",
			 "<img srcset=\"https://example.com/blog/post1/a.png 1x, https://example.com/blog/post1/b.png 2x\">"),
			("<img srcset=\"a.png, b.png 2x\">",
			 "<img srcset=\"https://example.com/blog/post1/a.png, https://example.com/blog/post1/b.png 2x\">"),
			("<img srcset=\"a.png 1x,b.png 2x\">",
			 "<img srcset=\"https://example.com/blog/post1/a.png 1x,https://example.com/blog/post1/b.png 2x\">"),
			("<img srcset=\"https://other.example.com/a.png 1x, b.png 2x\">",
			 "<img srcset=\"https://other.example.com/a.png 1x, https://example.com/blog/post1/b.png 2x\">")
		]
		for c in cases {
			#expect(resolved(c.input) == c.expected, "mismatch for \(c.input)")
		}
	}

	@Test func surroundingWhitespaceInValuesIsIgnoredAndPreserved() {
		// Whitespace can't hide a fragment-only href from the skip rule.
		#expect(resolved("<a href=\" #fn1\">x</a>") == "<a href=\" #fn1\">x</a>")

		// A padded relative value resolves — the padding stays in place.
		#expect(resolved("<a href=\" page.html \">x</a>") == "<a href=\" https://example.com/blog/post1/page.html \">x</a>")
	}

	@Test func similarlyNamedCloseTagDoesNotEndRawText() {
		// </scripty> is not </script> — everything inside stays untouched.
		let html = "<script>if (a</scripty>b) { s = '<img src=\"x.png\">'; }</script>"
		#expect(resolved(html) == html)
	}

	// MARK: - Malformed input

	@Test func malformedInputIsSafe() {
		// Unterminated quote: scanning stops, input preserved.
		let unterminated = "<a href=\"never closed"
		#expect(resolved(unterminated) == unterminated)

		// Well-formed replacement before the malformed tag still happens.
		let mixed = "<img src=\"a.png\"><a href=\"never closed"
		#expect(resolved(mixed) == "<img src=\"https://example.com/blog/post1/a.png\"><a href=\"never closed")

		let atEOF = "<a href="
		#expect(resolved(atEOF) == atEOF)

		let strayLessThan = "1 < 2 and <a href=\"x\">y</a>"
		#expect(resolved(strayLessThan) == "1 < 2 and <a href=\"https://example.com/blog/post1/x\">y</a>")
	}

	// MARK: - No-op guarantee

	@Test func allAbsoluteDocumentIsUnchanged() {
		let html = """
		<p>Intro text with an <a href="https://example.org/a">absolute link</a>.</p>
		<img src="https://example.org/img.png" srcset="https://example.org/img.png 1x">
		<p>More text, an <a href="#fn1">footnote</a>, and an <a href="">empty href</a>.</p>
		"""
		#expect(resolved(html) == html)
	}

	@Test func mixedDocumentIsSurgical() {
		// Everything outside the two rewritten values is byte-identical —
		// whitespace, attribute order, quoting, the non-URL attributes.
		let html = """
		<figure class='pic'>
			<picture>
				<source srcset="shot_light.png" media="(prefers-color-scheme: light)" width="1280" height="720"/>
				<img src="shot.png" width="1280" height="720" alt="A screenshot"/>
			</picture>
			<figcaption>Caption &amp; more</figcaption>
		</figure>
		"""
		let expected = """
		<figure class='pic'>
			<picture>
				<source srcset="https://example.com/blog/post1/shot_light.png" media="(prefers-color-scheme: light)" width="1280" height="720"/>
				<img src="https://example.com/blog/post1/shot.png" width="1280" height="720" alt="A screenshot"/>
			</picture>
			<figcaption>Caption &amp; more</figcaption>
		</figure>
		"""
		#expect(resolved(html) == expected)
	}

	// MARK: - Bytes entry point

	@Test func bytesEntryPointMatchesStringEntryPoint() {
		let html = "<img src=\"img.png\">"
		let bytes = Array(html.utf8)[...]
		let fromBytes = HTMLRelativeURLResolver.resolvingRelativeURLs(inBytes: bytes, baseURL: base)
		#expect(fromBytes == resolved(html))

		let absolute = "<img src=\"https://example.org/img.png\">"
		let absoluteBytes = Array(absolute.utf8)[...]
		#expect(HTMLRelativeURLResolver.resolvingRelativeURLs(inBytes: absoluteBytes, baseURL: base) == absolute)
	}
}
