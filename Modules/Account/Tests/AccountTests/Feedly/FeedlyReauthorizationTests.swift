//
//  FeedlyReauthorizationTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 9/16/26.
//

import Testing
import RSWeb
import Secrets
@testable import Account

@Suite(.isolatedWebserviceResponses) @MainActor struct FeedlyReauthorizationTests {

	private static let tokenEndpoint = "/v3/auth/token"

	/// Every 401 in a refresh cycle used to spawn its own token POST, which is the
	/// abuse pattern that earns a 403 ban from Feedly.
	@Test func aRejectedRefreshTokenIsOnlyTriedOnce() async throws {
		TestingURLProtocol.setResponse(.init(statusCode: 400), forURLContaining: Self.tokenEndpoint, httpMethod: HTTPMethod.post)

		let account = TestAccountManager.shared.createAccount(type: .feedly)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		let delegate = try #require(account.delegate as? FeedlyAccountDelegate)
		try account.storeCredentials(Credentials(type: .oauthRefreshToken, username: "someone", secret: "rejected-token"))

		let firstResult = await delegate.reauthorizeFeedlyAPICaller()
		#expect(firstResult == false)
		#expect(TestingURLProtocol.requestCount(forURLContaining: Self.tokenEndpoint) == 1)

		let secondResult = await delegate.reauthorizeFeedlyAPICaller()
		#expect(secondResult == false)
		#expect(TestingURLProtocol.requestCount(forURLContaining: Self.tokenEndpoint) == 1)
	}

	/// The account has to recover when the user signs in again, rather than staying
	/// dead until relaunch.
	@Test func newCredentialsAllowAnotherAttempt() async throws {
		TestingURLProtocol.setResponse(.init(statusCode: 400), forURLContaining: Self.tokenEndpoint, httpMethod: HTTPMethod.post)

		let account = TestAccountManager.shared.createAccount(type: .feedly)
		defer {
			TestAccountManager.shared.deleteAccount(account)
		}
		let delegate = try #require(account.delegate as? FeedlyAccountDelegate)
		try account.storeCredentials(Credentials(type: .oauthRefreshToken, username: "someone", secret: "rejected-token"))

		_ = await delegate.reauthorizeFeedlyAPICaller()
		#expect(TestingURLProtocol.requestCount(forURLContaining: Self.tokenEndpoint) == 1)

		try account.storeCredentials(Credentials(type: .oauthAccessToken, username: "someone", secret: "fresh-token"))

		_ = await delegate.reauthorizeFeedlyAPICaller()
		#expect(TestingURLProtocol.requestCount(forURLContaining: Self.tokenEndpoint) == 2)
	}
}
