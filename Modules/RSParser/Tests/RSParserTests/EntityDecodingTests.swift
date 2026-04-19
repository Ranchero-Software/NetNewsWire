//
//  EntityDecodingTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 12/30/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Testing
import RSParser

@Suite struct EntityDecodingTests {

	@Test("Decimal entity &#39; (single-quote bug from micro.blog)")
	func decimalEntity39() {
		// Bug found by Manton Reece — the &#39; entity was not getting decoded
		// by NetNewsWire in JSON Feeds from micro.blog.
		let s = "These are the times that try men&#39;s souls."
		let decoded = s.rsparser_stringByDecodingHTMLEntities()
		#expect(decoded == "These are the times that try men's souls.")
	}

	@Test("Decimal and hex entities decode to the same characters",
	      arguments: [
	          ("&#8230;", "…"),
	          ("&#x2026;", "…"),
	          ("&#039;", "'"),
	          ("&#167;", "§"),
	          ("&#XA3;", "£")
	      ])
	func entityPair(_ input: String, _ expected: String) {
		#expect(input.rsparser_stringByDecodingHTMLEntities() == expected)
	}
}
