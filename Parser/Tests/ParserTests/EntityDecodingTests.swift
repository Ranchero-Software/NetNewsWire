//
//  EntityDecodingTests.swift
//  ParserTests
//
//  Created by Brent Simmons on 12/30/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Parser

final class EntityDecodingTests: XCTestCase {

    func test39Decoding() {

		// Bug found by Manton Reece — the &#39; entity was not getting decoded by NetNewsWire in JSON Feeds from micro.blog.

		let s = "These are the times that try men&#39;s souls."
		let decoded = decodedString(s)

		XCTAssertEqual(decoded, "These are the times that try men's souls.")
	}

	func testEntityAtBeginning() {

		let s = "&#39;leading single quote"
		let decoded = decodedString(s)

		XCTAssertEqual(decoded, "'leading single quote")
	}

	func testEntityAtEnd() {

		let s = "trailing single quote&#39;"
		let decoded = decodedString(s)

		XCTAssertEqual(decoded, "trailing single quote'")
	}

	func testEntityInMiddle() {

		let s = "entity &ccedil; in middle"
		let decoded = decodedString(s)

		XCTAssertEqual(decoded, "entity ç in middle")
	}

	func testMultipleEntitiesInARow() {

		let s = "&ccedil;&egrave;mult&#8230;&#x2026;iple &#39;&aelig;&quot;entities&divide;&hearts;"
		let decoded = decodedString(s)

		XCTAssertEqual(decoded, "çèmult……iple 'æ\"entities÷♥")
	}

	func testFakeoutEntities() {

		var s = "&&;&#;&#x;&#X;&  ;&#  \t;&\r&&&&&;"
		XCTAssertEqual(decodedString(s), s)

		s = "#;&#x;&#X;& &#123"
		XCTAssertEqual(decodedString(s), s)

		s = "  &lsquo "
		XCTAssertEqual(decodedString(s), s)

		s = "&&&&&&&&&&&&&&&&&&&;;;;;;&;&;&##;#X::&;&;&;&"
		XCTAssertEqual(decodedString(s), s)
	}

	func testFakeSquirrelEntities() {

		var s = "&squirrel;"
		XCTAssertEqual(decodedString(s), s)

		s = "&squirrel;&#squirrel;"
		XCTAssertEqual(decodedString(s), s)

		s = "&squirrel;&#squirrel;&#xsquirrel;&#Xsquirrel;"
		XCTAssertEqual(decodedString(s), s)

		s = "&#39squirrel;"
		XCTAssertEqual(decodedString(s), s)

		s = "&squirrel;&#squirrel;&#xsquirrel;&#Xsquirrel;&#39squirrel;"
		XCTAssertEqual(decodedString(s), s)

		s = "&squirrel;&#squirrel;&#xsquirrel;&#Xsquirrel;&#39squirrel;&&;;;;&;&;&#squi#;#rrelX::&;&;&;&"
		XCTAssertEqual(decodedString(s), s)
	}

	func testLongFakeoutEntities() {

		var s = "&thisIsALongNotRealEntityThatShouldBeHandledPerfectlyWellByTheParserBasicallyIgnored;"
		XCTAssertEqual(decodedString(s), s)

		s = "&#89437652094387502948360194365209348650293486752093487652093486752;"
		XCTAssertEqual(decodedString(s), s)

		s = "&#89437652094387502948360194365;"
		XCTAssertEqual(decodedString(s), s)

		s = "&#894376520943875029483601943651;"
		XCTAssertEqual(decodedString(s), s)

		s = "&#1114112;"
		XCTAssertEqual(decodedString(s), s)

		s = "&#x110000;"
		XCTAssertEqual(decodedString(s), s)
	}

	func testOnlyEntity() {
		var s = "&#8230;"
		var decoded = decodedString(s)

		XCTAssertEqual(decoded, "…")

		s = "&#x2026;"
		decoded = decodedString(s)
		XCTAssertEqual(decoded, "…")

		s = "&#039;"
		decoded = decodedString(s)
		XCTAssertEqual(decoded, "'")

		s = "&#167;"
		decoded = decodedString(s)
		XCTAssertEqual(decoded, "§")

		s = "&#XA3;"
		decoded = decodedString(s)
		XCTAssertEqual(decoded, "£")
	}

	func testPerformance() {

		// 0.003 sec on my M1 Mac Studio.
		let s = stringForResource("DaringFireball", "html")

		self.measure {
			_ = decodedString(s)
		}
	}
}

func stringForResource(_ filename: String, _ fileExtension: String) -> String {

	let filename = "Resources/\(filename)"
	let path = Bundle.module.path(forResource: filename, ofType: fileExtension)!
	return try! String(contentsOfFile: path)
}

func decodedString(_ s: String) -> String {

	HTMLEntityDecoder.decodedString(s)
}
