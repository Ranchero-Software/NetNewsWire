//
//  TestingURLProtocolRequestCountTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 9/16/26.
//

import Foundation
import Testing
import RSCore
@testable import RSWeb

struct TestingURLProtocolRequestCountTests {

	private static let url = URL(string: "https://example.com/v3/auth/token")!
	private static let urlSubstring = "/v3/auth/token"

	@Test func requestsAreCounted() async throws {
		try #require(Platform.isRunningUnitTests)

		try await Self.withItsOwnResponses {
			TestingURLProtocol.setResponse(.init(statusCode: 400), forURLContaining: Self.urlSubstring)

			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring) == 0)

			try await Self.send(httpMethod: HTTPMethod.post)
			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring) == 1)

			try await Self.send(httpMethod: HTTPMethod.post)
			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring) == 2)
		}
	}

	@Test func countingCanBeNarrowedToOneMethod() async throws {
		try #require(Platform.isRunningUnitTests)

		try await Self.withItsOwnResponses {
			try await Self.send(httpMethod: HTTPMethod.post)
			try await Self.send(httpMethod: HTTPMethod.get)

			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring, httpMethod: HTTPMethod.post) == 1)
			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring, httpMethod: HTTPMethod.get) == 1)
			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring) == 2)
		}
	}

	/// A request with no registered response still counts, so a test can assert that a
	/// call it never stubbed was made — or wasn't.
	@Test func unstubbedRequestsAreCountedToo() async throws {
		try #require(Platform.isRunningUnitTests)

		try await Self.withItsOwnResponses {
			try await Self.send(httpMethod: HTTPMethod.get)

			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring) == 1)
			#expect(TestingURLProtocol.requestCount(forURLContaining: "/v3/never/called") == 0)
		}
	}

	@Test func anotherTestsRequestsAreNotCounted() async throws {
		try #require(Platform.isRunningUnitTests)

		try await Self.withItsOwnResponses {
			try await Self.send(httpMethod: HTTPMethod.post)

			let countInAnotherTest = try await TestingURLProtocol.$currentTestID.withValue("another-test") {
				try await Self.send(httpMethod: HTTPMethod.post)
				return TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring)
			}
			TestingURLProtocol.endTest(withID: "another-test")

			#expect(countInAnotherTest == 1)
			#expect(TestingURLProtocol.requestCount(forURLContaining: Self.urlSubstring) == 1)
		}
	}
}

private extension TestingURLProtocolRequestCountTests {

	/// Runs `body` against its own response table. RSWebTests has no trait to do this
	/// (`IsolatedWebserviceResponsesTrait` lives in AccountTests), so it's done by hand.
	static func withItsOwnResponses(_ body: () async throws -> Void) async throws {
		let testID = UUID().uuidString
		try await TestingURLProtocol.$currentTestID.withValue(testID) {
			defer {
				TestingURLProtocol.endTest(withID: testID)
			}
			try await body()
		}
	}

	static func send(httpMethod: String) async throws {
		var request = URLRequest(url: url)
		request.httpMethod = httpMethod

		let session = URLSession.makeWebserviceSession()
		_ = try await session.data(for: request)
	}
}
