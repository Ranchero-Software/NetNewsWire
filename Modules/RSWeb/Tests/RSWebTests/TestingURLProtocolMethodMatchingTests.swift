//
//  TestingURLProtocolMethodMatchingTests.swift
//  RSWebTests
//
//  Created by Brent Simmons on 9/14/26.
//

import Foundation
import Testing
import RSCore
@testable import RSWeb

struct TestingURLProtocolMethodMatchingTests {

	private static let url = URL(string: "https://example.com/unread_entries.json")!
	private static let urlSubstring = "unread_entries.json"

	@Test func aMethodSpecificResponseAnswersOnlyThatMethod() async throws {
		try #require(Platform.isRunningUnitTests)

		try await Self.withItsOwnResponses {
			TestingURLProtocol.setResponse(.init(statusCode: 422), forURLContaining: Self.urlSubstring, httpMethod: HTTPMethod.post)

			let postStatusCode = try await Self.statusCode(httpMethod: HTTPMethod.post)
			#expect(postStatusCode == 422)

			let getStatusCode = try await Self.statusCode(httpMethod: HTTPMethod.get)
			#expect(getStatusCode == 200)
		}
	}

	@Test func aResponseWithNoMethodAnswersEveryMethod() async throws {
		try #require(Platform.isRunningUnitTests)

		try await Self.withItsOwnResponses {
			TestingURLProtocol.setResponse(.init(statusCode: 404), forURLContaining: Self.urlSubstring)

			let postStatusCode = try await Self.statusCode(httpMethod: HTTPMethod.post)
			#expect(postStatusCode == 404)

			let getStatusCode = try await Self.statusCode(httpMethod: HTTPMethod.get)
			#expect(getStatusCode == 404)

			let deleteStatusCode = try await Self.statusCode(httpMethod: HTTPMethod.delete)
			#expect(deleteStatusCode == 404)
		}
	}

	@Test func aMethodSpecificResponseWinsOverOneWithNoMethod() async throws {
		try #require(Platform.isRunningUnitTests)

		try await Self.withItsOwnResponses {
			TestingURLProtocol.setResponse(.init(statusCode: 404), forURLContaining: Self.urlSubstring)
			TestingURLProtocol.setResponse(.init(statusCode: 422), forURLContaining: Self.urlSubstring, httpMethod: HTTPMethod.post)

			let postStatusCode = try await Self.statusCode(httpMethod: HTTPMethod.post)
			#expect(postStatusCode == 422)

			let getStatusCode = try await Self.statusCode(httpMethod: HTTPMethod.get)
			#expect(getStatusCode == 404)
		}
	}
}

private extension TestingURLProtocolMethodMatchingTests {

	/// Runs `body` against its own response table. RSWebTests has no trait to do this
	/// (`IsolatedWebserviceResponsesTrait` lives in AccountTests), so it's done by hand —
	/// without it these tests share one table and clear each other's registrations.
	static func withItsOwnResponses(_ body: () async throws -> Void) async throws {
		let testID = UUID().uuidString
		try await TestingURLProtocol.$currentTestID.withValue(testID) {
			defer {
				TestingURLProtocol.removeResponses(forTestID: testID)
			}
			try await body()
		}
	}

	static func statusCode(httpMethod: String) async throws -> Int {
		var request = URLRequest(url: url)
		request.httpMethod = httpMethod

		let session = URLSession.makeWebserviceSession()
		let (_, response) = try await session.data(for: request)
		return try #require(response as? HTTPURLResponse).statusCode
	}
}
