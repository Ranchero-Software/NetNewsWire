//
//  MinifluxVersionTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/8/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Testing
@testable import Account

struct MinifluxVersionTests {

	@Test func comparesNumericallyNotLexicographically() {
		#expect(MinifluxVersion(2, 3, 10) > MinifluxVersion(2, 3, 2))
	}

	@Test func parsesDevSuffixAndMissingComponent() {
		#expect(MinifluxVersion(string: "2.3.2-dev") == MinifluxVersion(2, 3, 2))
		#expect(MinifluxVersion(string: "2.3") == MinifluxVersion(2, 3, 0))
	}

	@Test func whollyNonNumericStringFailsToParse() {
		#expect(MinifluxVersion(string: "dev") == nil)
	}
}
