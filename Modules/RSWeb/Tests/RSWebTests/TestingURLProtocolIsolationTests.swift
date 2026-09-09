//
//  TestingURLProtocolIsolationTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 9/7/26.
//

import Foundation
import Testing
import RSCore
@testable import RSWeb

struct TestingURLProtocolIsolationTests {

	private static let url = URL(string: "https://example.com/subscriptions.json")!
	private static let urlSubstring = "subscriptions.json"

	@Test func concurrentTestsDoNotSeeEachOthersResponses() async throws {
		try #require(Platform.isRunningUnitTests)

		async let first = Self.statusCode(forTestID: "first", registering: 418)
		async let second = Self.statusCode(forTestID: "second", registering: 503)

		let (firstStatusCode, secondStatusCode) = try await (first, second)
		#expect(firstStatusCode == 418)
		#expect(secondStatusCode == 503)
	}

	@Test func resetClearsOnlyTheCurrentTestsResponses() async throws {
		try #require(Platform.isRunningUnitTests)

		TestingURLProtocol.$currentTestID.withValue("keeper") {
			TestingURLProtocol.setResponse(.init(statusCode: 418), forURLContaining: Self.urlSubstring)
		}
		defer {
			TestingURLProtocol.removeResponses(forTestID: "keeper")
		}

		TestingURLProtocol.$currentTestID.withValue("resetter") {
			TestingURLProtocol.setResponse(.init(statusCode: 503), forURLContaining: Self.urlSubstring)
			TestingURLProtocol.reset()
		}

		let statusCode = try await TestingURLProtocol.$currentTestID.withValue("keeper") {
			try await Self.statusCode(for: Self.url)
		}
		#expect(statusCode == 418)
	}

	@Test func aSessionBuiltOutsideATestScopeUsesTheSharedResponses() async throws {
		try #require(Platform.isRunningUnitTests)

		TestingURLProtocol.setResponse(.init(statusCode: 404), forURLContaining: Self.urlSubstring)
		defer {
			TestingURLProtocol.reset()
		}

		let statusCode = try await Self.statusCode(for: Self.url)
		#expect(statusCode == 404)
	}
}

private extension TestingURLProtocolIsolationTests {

	/// Registers a response and fetches it, all inside one test-ID scope, so the session
	/// created here carries that ID.
	static func statusCode(forTestID testID: String, registering statusCode: Int) async throws -> Int {
		try await TestingURLProtocol.$currentTestID.withValue(testID) {
			defer {
				TestingURLProtocol.removeResponses(forTestID: testID)
			}
			TestingURLProtocol.setResponse(.init(statusCode: statusCode), forURLContaining: urlSubstring)
			return try await Self.statusCode(for: url)
		}
	}

	static func statusCode(for url: URL) async throws -> Int {
		let session = URLSession.makeWebserviceSession()
		let (_, response) = try await session.data(from: url)
		return try #require(response as? HTTPURLResponse).statusCode
	}
}
