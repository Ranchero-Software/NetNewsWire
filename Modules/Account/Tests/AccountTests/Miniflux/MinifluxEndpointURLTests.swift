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
		#expect(Miniflux.normalizedEndpointURL(from: " miniflux.example.com/v1/ ") == URL(string: "https://miniflux.example.com"))
	}

	@Test func schemeWithNoHostIsRejected() {
		#expect(Miniflux.normalizedEndpointURL(from: "https://") == nil)
	}
}
