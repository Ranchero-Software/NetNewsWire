//
//  MinifluxVersionTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/8/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

final class MinifluxVersionTests: XCTestCase {

	func testParsesSimpleVersionString() throws {
		let version = try XCTUnwrap(MinifluxVersion(string: "2.3.2"))
		XCTAssertGreaterThanOrEqual(version, MinifluxVersion(2, 3, 2))
		XCTAssertEqual(version, MinifluxVersion(2, 3, 2))
	}

	func testComparesNumericallyNotLexicographically() {
		XCTAssertGreaterThan(MinifluxVersion(2, 3, 10), MinifluxVersion(2, 3, 2))
	}

	func testOlderMinorVersionIsLess() {
		XCTAssertLessThan(MinifluxVersion(2, 2, 17), MinifluxVersion(2, 3, 2))
	}

	func testParsesNonNumericSuffixOnLastComponent() throws {
		let version = try XCTUnwrap(MinifluxVersion(string: "2.3.2-dev"))
		XCTAssertEqual(version, MinifluxVersion(2, 3, 2))
	}

	func testMissingComponentIsTreatedAsZero() throws {
		let version = try XCTUnwrap(MinifluxVersion(string: "2.3"))
		XCTAssertEqual(version, MinifluxVersion(2, 3, 0))
	}

	func testWhollyNonNumericStringFailsToParse() {
		XCTAssertNil(MinifluxVersion(string: "dev"))
	}
}
