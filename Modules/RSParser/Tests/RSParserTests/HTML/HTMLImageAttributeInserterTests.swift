//
//  HTMLImageAttributeInserterTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 10/27/26.
//

import Foundation
import Testing
import RSParser

@Suite struct HTMLImageAttributeInserterTests {

	@Test func attributesAreInsertedIntoImagesWhoseSourceResolvesToURL() {
		let html = """
		<p>Café</p><img src="/images/photo.jpg" alt="Photo"><IMG SRC="https://example.com/images/photo.jpg">\
		<img src="/images/photo.jpg" srcset="/images/photo-2x.jpg 2x"><picture><img src="/images/photo.jpg"></picture>\
		<img src="/images/other.jpg">
		"""
		let result = HTMLImageAttributeInserter.insertingAttributes(" src=\"nnw:x\"", intoImagesWithSource: "https://example.com/images/photo.jpg", html: html, baseURL: "https://example.com/2026/10/post.html")

		let expected = """
		<p>Café</p><img src="nnw:x" src="/images/photo.jpg" alt="Photo"><IMG src="nnw:x" SRC="https://example.com/images/photo.jpg">\
		<img src="/images/photo.jpg" srcset="/images/photo-2x.jpg 2x"><picture><img src="/images/photo.jpg"></picture>\
		<img src="/images/other.jpg">
		"""
		#expect(result == expected)
	}

	@Test func imagesWrittenAsTextInTextareaAreLeftAlone() {
		let html = #"<textarea>Embed: <img src="/images/photo.jpg"></textarea><img src="/images/photo.jpg">"#
		let result = HTMLImageAttributeInserter.insertingAttributes(" src=\"nnw:x\"", intoImagesWithSource: "https://example.com/images/photo.jpg", html: html, baseURL: "https://example.com/")

		#expect(result == #"<textarea>Embed: <img src="/images/photo.jpg"></textarea><img src="nnw:x" src="/images/photo.jpg">"#)
	}
}
