//
//  AccountManagerDuplicateEndpointTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

@MainActor final class AccountManagerDuplicateEndpointTests: XCTestCase {

	func testCaseInsensitiveHostMatches() {
		let a = AccountManager.normalizedEndpointForComparison(URL(string: "https://Miniflux.Example.com"))
		let b = AccountManager.normalizedEndpointForComparison(URL(string: "https://miniflux.example.com"))
		XCTAssertEqual(a, b)
	}

	func testTrailingSlashIsIgnored() {
		let a = AccountManager.normalizedEndpointForComparison(URL(string: "https://miniflux.example.com/"))
		let b = AccountManager.normalizedEndpointForComparison(URL(string: "https://miniflux.example.com"))
		XCTAssertEqual(a, b)
	}

	func testDifferentPathsDoNotMatch() {
		let a = AccountManager.normalizedEndpointForComparison(URL(string: "https://example.com/miniflux"))
		let b = AccountManager.normalizedEndpointForComparison(URL(string: "https://example.com/other"))
		XCTAssertNotEqual(a, b)
	}

	func testNilURLNormalizesToNil() {
		XCTAssertNil(AccountManager.normalizedEndpointForComparison(nil))
	}
}
