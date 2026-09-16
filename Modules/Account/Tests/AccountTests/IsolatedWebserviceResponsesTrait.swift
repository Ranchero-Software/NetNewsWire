//
//  IsolatedWebserviceResponsesTrait.swift
//  AccountTests
//
//  Created by Brent Simmons on 9/9/26.
//

import Foundation
import Testing
import RSWeb

/// Gives each test its own `TestingURLProtocol` response table, so suites that stub
/// webservice responses can run in parallel without seeing each other's registrations.
///
/// Apply it to a suite. It's recursive, so every test in that suite — and in any suite
/// nested inside it — gets a fresh table, and the table is discarded when the test ends.
struct IsolatedWebserviceResponsesTrait: TestTrait, SuiteTrait, TestScoping {

	var isRecursive: Bool {
		true
	}

	func provideScope(for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
		let testID = UUID().uuidString
		try await TestingURLProtocol.$currentTestID.withValue(testID) {
			defer {
				TestingURLProtocol.endTest(withID: testID)
			}
			try await function()
		}
	}
}

extension Trait where Self == IsolatedWebserviceResponsesTrait {

	/// Gives each test its own `TestingURLProtocol` response table.
	static var isolatedWebserviceResponses: Self {
		Self()
	}
}
