//
//  EntityDecodingTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 12/30/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Parser

class EntityDecodingTests: XCTestCase {

    func test39Decoding() {

		// Bug found by Manton Reece — the &#39; entity was not getting decoded by NetNewsWire in JSON Feeds from micro.blog.

		let s = "These are the times that try men&#39;s souls."
		let decoded = s.rsparser_stringByDecodingHTMLEntities()

		XCTAssertEqual(decoded, "These are the times that try men's souls.")
	}

	func testEntities() {
		var s = "&#8230;"
		var decoded = s.rsparser_stringByDecodingHTMLEntities()

		XCTAssertEqual(decoded, "…")

		s = "&#x2026;"
		decoded = s.rsparser_stringByDecodingHTMLEntities()
		XCTAssertEqual(decoded, "…")

		s = "&#039;"
		decoded = s.rsparser_stringByDecodingHTMLEntities()
		XCTAssertEqual(decoded, "'")

		s = "&#167;"
		decoded = s.rsparser_stringByDecodingHTMLEntities()
		XCTAssertEqual(decoded, "§")

		s = "&#XA3;"
		decoded = s.rsparser_stringByDecodingHTMLEntities()
		XCTAssertEqual(decoded, "£")

	}
}
