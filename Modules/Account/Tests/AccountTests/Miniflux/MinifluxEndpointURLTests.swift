//
//  MinifluxEndpointURLTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 11/25/26.
//

import Foundation
import Testing
@testable import Account

@MainActor struct MinifluxEndpointURLTests {

	@Test func pastedAPIURLBecomesBaseURL() {
		#expect(Account.normalizedMinifluxEndpointURL(from: " miniflux.example.com/v1/ ") == URL(string: "https://miniflux.example.com"))
	}

	@Test func schemeWithNoHostIsRejected() {
		#expect(Account.normalizedMinifluxEndpointURL(from: "https://") == nil)
	}
}
