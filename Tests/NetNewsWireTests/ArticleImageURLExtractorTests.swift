//
//  ArticleImageURLExtractorTests.swift
//  NetNewsWireTests
//
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import XCTest

@testable import NetNewsWire

final class ArticleImageURLExtractorTests: XCTestCase {

	private func urls(_ html: String, base: String? = nil) -> [String] {
		let baseURL = base.flatMap { URL(string: $0) }
		return ArticleImageURLExtractor.imageURLStrings(in: html, baseURL: baseURL)
	}

	func testAbsoluteURL() {
		let result = urls("<p><img src=\"https://example.com/a.jpg\"></p>")
		XCTAssertEqual(result, ["https://example.com/a.jpg"])
	}

	func testRelativeURLResolvesAgainstBase() {
		let result = urls("<img src=\"/images/a.jpg\">", base: "https://example.com/posts/1")
		XCTAssertEqual(result, ["https://example.com/images/a.jpg"])
	}

	func testProtocolRelativeURLUsesBaseScheme() {
		let result = urls("<img src=\"//cdn.example.com/a.jpg\">", base: "http://example.com/")
		XCTAssertEqual(result, ["http://cdn.example.com/a.jpg"])
	}

	func testProtocolRelativeURLDefaultsToHTTPSWithoutBase() {
		let result = urls("<img src=\"//cdn.example.com/a.jpg\">")
		XCTAssertEqual(result, ["https://cdn.example.com/a.jpg"])
	}

	func testDataCanonicalSrcPreferredOverSrc() {
		let html = "<img data-canonical-src=\"https://real.example.com/a.jpg\" src=\"https://proxy.example.com/a.jpg\">"
		XCTAssertEqual(urls(html), ["https://real.example.com/a.jpg"])
	}

	func testUppercaseSchemeIsLowercased() {
		// The browser lowercases the scheme in element.src, so the prefetch key must match.
		XCTAssertEqual(urls("<img src=\"HTTPS://example.com/a.jpg\">"), ["https://example.com/a.jpg"])
	}

	func testHTMLEntitiesInURLAreDecoded() {
		let html = "<img src=\"https://example.com/a.jpg?w=1&amp;h=2\">"
		XCTAssertEqual(urls(html), ["https://example.com/a.jpg?w=1&h=2"])
	}

	func testNonHTTPSchemesAreRejected() {
		let html = """
		<img src="data:image/png;base64,iVBORw0KG">
		<img src="file:///etc/passwd">
		<img src="ftp://example.com/a.jpg">
		"""
		XCTAssertEqual(urls(html), [])
	}

	func testRelativeURLWithoutBaseIsSkipped() {
		XCTAssertEqual(urls("<img src=\"/images/a.jpg\">"), [])
	}

	func testDuplicatesAreDeduplicated() {
		let html = "<img src=\"https://example.com/a.jpg\"><img src=\"https://example.com/a.jpg\">"
		XCTAssertEqual(urls(html), ["https://example.com/a.jpg"])
	}

	func testMultipleImagesPreserveOrder() {
		let html = "<img src=\"https://example.com/a.jpg\"><img src=\"https://example.com/b.jpg\">"
		XCTAssertEqual(urls(html), ["https://example.com/a.jpg", "https://example.com/b.jpg"])
	}

	func testSingleQuotedAttribute() {
		let result = urls("<img src='https://example.com/a.jpg'>")
		XCTAssertEqual(result, ["https://example.com/a.jpg"])
	}

	func testNoImages() {
		XCTAssertEqual(urls("<p>No images here.</p>"), [])
	}

	func testBatchDeduplicatesAcrossInputs() {
		let inputs = [
			ArticleImageURLExtractor.Input(html: "<img src=\"https://example.com/a.jpg\">", baseURLString: nil),
			ArticleImageURLExtractor.Input(html: "<img src=\"https://example.com/a.jpg\"><img src=\"https://example.com/b.jpg\">", baseURLString: nil)
		]
		XCTAssertEqual(ArticleImageURLExtractor.imageURLStrings(in: inputs), ["https://example.com/a.jpg", "https://example.com/b.jpg"])
	}
}
