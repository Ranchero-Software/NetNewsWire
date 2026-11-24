//
//  MinifluxKeychainServerTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 11/24/26.
//

import Foundation
import Testing
@testable import Account

@MainActor struct MinifluxKeychainServerTests {

	@Test func serverIncludesPortAndPath() {
		#expect(server(for: "https://example.com/miniflux/") == "example.com/miniflux")
		#expect(server(for: "https://example.com:8443/miniflux") == "example.com:8443/miniflux")
		#expect(server(for: "https://example.com/") == "example.com")
	}
}

// MARK: - Helpers

@MainActor private func server(for urlString: String) -> String? {
	let accountSettings = AccountSettings(accountID: UUID().uuidString, dataFolder: NSTemporaryDirectory())
	defer {
		accountSettings.deleteSettings()
	}
	accountSettings.endpointURL = URL(string: urlString)

	let caller = MinifluxAPICaller()
	caller.accountSettings = accountSettings
	return caller.server
}
