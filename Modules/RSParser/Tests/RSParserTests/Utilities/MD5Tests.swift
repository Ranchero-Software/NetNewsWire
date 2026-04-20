//
//  MD5Tests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/19/26.
//

import Testing
@testable import RSParser

@Suite struct MD5Tests {

	@Test("Empty string MD5")
	func emptyString() {
		#expect("".md5String == "d41d8cd98f00b204e9800998ecf8427e")
	}

	@Test("Known vectors",
	      arguments: [
	          ("abc", "900150983cd24fb0d6963f7d28e17f72"),
	          ("The quick brown fox jumps over the lazy dog", "9e107d9d372bb6826bd81d3542a419d6")
	      ])
	func knownVector(_ input: String, _ expected: String) {
		#expect(input.md5String == expected)
	}

	@Test("Output is 32 lowercase hex characters")
	func formatIs32LowercaseHex() {
		let hash = "arbitrary input".md5String
		#expect(hash.count == 32)
		#expect(hash.allSatisfy { c in
			("0"..."9").contains(c) || ("a"..."f").contains(c)
		})
	}
}
