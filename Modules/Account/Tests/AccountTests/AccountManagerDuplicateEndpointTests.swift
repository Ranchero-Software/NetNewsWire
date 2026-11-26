//
//  AccountManagerDuplicateEndpointTests.swift
//  AccountTests
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Testing
@testable import Account

@MainActor struct AccountManagerDuplicateEndpointTests {

	@Test func hostCaseTrailingSlashSchemeAndDefaultPortAreIgnored() {
		let endpoint = AccountManager.normalizedEndpointForComparison(URL(string: "https://miniflux.example.com"))
		#expect(AccountManager.normalizedEndpointForComparison(URL(string: "https://Miniflux.Example.com/")) == endpoint)
		#expect(AccountManager.normalizedEndpointForComparison(URL(string: "https://miniflux.example.com:443")) == endpoint)
		#expect(AccountManager.normalizedEndpointForComparison(URL(string: "http://miniflux.example.com")) == endpoint)
	}

	@Test func differentPathsDoNotMatch() {
		let first = AccountManager.normalizedEndpointForComparison(URL(string: "https://example.com/miniflux"))
		let second = AccountManager.normalizedEndpointForComparison(URL(string: "https://example.com/other"))
		#expect(first != second)
	}

	@Test func duplicateRequiresSameUsernameAndServer() {
		let existingAccount = TestAccountManager.shared.createAccount(type: .miniflux)
		defer {
			TestAccountManager.shared.deleteAccount(existingAccount)
		}
		existingAccount.username = "admin"
		existingAccount.endpointURL = URL(string: "https://first.miniflux.test")

		#expect(AccountManager.duplicateServiceAccount(type: .miniflux, username: "admin", endpoint: URL(string: "https://first.miniflux.test"), among: [existingAccount]))
		#expect(!AccountManager.duplicateServiceAccount(type: .miniflux, username: "admin", endpoint: URL(string: "https://second.miniflux.test"), among: [existingAccount]))
		#expect(!AccountManager.duplicateServiceAccount(type: .miniflux, username: "claude", endpoint: URL(string: "https://first.miniflux.test"), among: [existingAccount]))
	}
}
