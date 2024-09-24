//
//  EntityDecodingTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 12/30/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import SAX

final class EntityDecodingTests: XCTestCase {

    func test39Decoding() {

		// Bug found by Manton Reece — the &#39; entity was not getting decoded by NetNewsWire in JSON Feeds from micro.blog.

		let s = "These are the times that try men&#39;s souls."
		let decoded = HTMLEntityDecoder.decodedString(s)

		XCTAssertEqual(decoded, "These are the times that try men's souls.")
	}

	func testEntityAtBeginning() {

		let s = "&#39;leading single quote"
		let decoded = HTMLEntityDecoder.decodedString(s)

		XCTAssertEqual(decoded, "'leading single quote")
	}

	func testEntityAtEnd() {

		let s = "trailing single quote&#39;"
		let decoded = HTMLEntityDecoder.decodedString(s)

		XCTAssertEqual(decoded, "trailing single quote'")
	}

	func testEntityInMiddle() {

		let s = "entity &ccedil; in middle"
		let decoded = HTMLEntityDecoder.decodedString(s)

		XCTAssertEqual(decoded, "entity ç in middle")
	}

	func testMultipleEntitiesInARow() {

		let s = "&ccedil;&egrave;mult&#8230;&#x2026;iple &#39;&aelig;&quot;entities&divide;&hearts;"
		let decoded = HTMLEntityDecoder.decodedString(s)

		XCTAssertEqual(decoded, "çèmult……iple 'æ\"entities÷♥")
	}

	func testOnlyEntity() {
		var s = "&#8230;"
		var decoded = HTMLEntityDecoder.decodedString(s)

		XCTAssertEqual(decoded, "…")

		s = "&#x2026;"
		decoded = HTMLEntityDecoder.decodedString(s)
		XCTAssertEqual(decoded, "…")

		s = "&#039;"
		decoded = HTMLEntityDecoder.decodedString(s)
		XCTAssertEqual(decoded, "'")

		s = "&#167;"
		decoded = HTMLEntityDecoder.decodedString(s)
		XCTAssertEqual(decoded, "§")

		s = "&#XA3;"
		decoded = HTMLEntityDecoder.decodedString(s)
		XCTAssertEqual(decoded, "£")
	}
}
