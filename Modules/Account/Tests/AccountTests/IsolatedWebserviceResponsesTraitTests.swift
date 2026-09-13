//
//  IsolatedWebserviceResponsesTraitTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 9/9/26.
//

import Foundation
import Testing
import RSWeb

@Suite(.isolatedWebserviceResponses) struct IsolatedWebserviceResponsesTraitTests {

	private static let url = URL(string: "https://example.com/subscriptions.json")!

	@Test func theTraitBindsATestID() {
		#expect(TestingURLProtocol.currentTestID != nil)
	}

	@Test func responsesRegisteredHereAreInvisibleUnderAnotherTestID() async throws {
		TestingURLProtocol.setResponse(.init(statusCode: 418), forURLContaining: "subscriptions.json")

		let mine = try await Self.statusCode()
		#expect(mine == 418)

		let theirs = try await TestingURLProtocol.$currentTestID.withValue("another-test") {
			try await Self.statusCode()
		}
		#expect(theirs == 200)
	}
}

private extension IsolatedWebserviceResponsesTraitTests {

	static func statusCode() async throws -> Int {
		let session = URLSession.makeWebserviceSession()
		let (_, response) = try await session.data(from: url)
		return try #require(response as? HTTPURLResponse).statusCode
	}
}
