//
//  FeedlyRefreshAccessTokenOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 4/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSWeb
import RSCore
import Secrets

class FeedlyRefreshAccessTokenOperationTests: XCTestCase {
	
	private var account: Account!
	private let support = FeedlyTestSupport()
	
	override func setUp() {
		super.setUp()
		account = support.makeTestAccount()
	}
	
	override func tearDown() {
		if let account = account {
			support.destroy(account)
		}
		super.tearDown()
	}
	
	class TestRefreshTokenService: OAuthAccessTokenRefreshing {
		var mockResult: Result<OAuthAuthorizationGrant, Error>?
		var refreshAccessTokenExpectation: XCTestExpectation?
		var parameterTester: ((String, OAuthAuthorizationClient) -> ())?
		
		func refreshAccessToken(with refreshToken: String, client: OAuthAuthorizationClient, completion: @escaping (Result<OAuthAuthorizationGrant, Error>) -> ()) {
			
			guard let result = mockResult else {
				XCTFail("Missing mock result. Test may time out because the completion will not be called.")
				return
			}
			parameterTester?(refreshToken, client)
			DispatchQueue.main.async {
				completion(result)
				self.refreshAccessTokenExpectation?.fulfill()
			}
		}
	}
	
	func testCancel() {
		let service = TestRefreshTokenService()
		service.refreshAccessTokenExpectation = expectation(description: "Did Call Refresh")
		service.refreshAccessTokenExpectation?.isInverted = true
		
		let client = support.makeMockOAuthClient()
		let refresh = FeedlyRefreshAccessTokenOperation(account: account, service: service, oauthClient: client, log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		refresh.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(refresh)
		
		MainThreadOperationQueue.shared.cancelOperations([refresh])
		
		waitForExpectations(timeout: 1)
		
		XCTAssertTrue(refresh.isCanceled)
	}
	
	class TestRefreshTokenDelegate: FeedlyOperationDelegate {
		var error: Error?
		var didFailExpectation: XCTestExpectation?
		
		func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
			self.error = error
			didFailExpectation?.fulfill()
		}
	}
	
	func testMissingRefreshToken() {
		support.removeCredentials(matching: .oauthRefreshToken, from: account)
		
		let service = TestRefreshTokenService()
		service.refreshAccessTokenExpectation = expectation(description: "Did Call Refresh")
		service.refreshAccessTokenExpectation?.isInverted = true
		
		let client = support.makeMockOAuthClient()
		let refresh = FeedlyRefreshAccessTokenOperation(account: account, service: service, oauthClient: client, log: support.log)
		
		let delegate = TestRefreshTokenDelegate()
		delegate.didFailExpectation = expectation(description: "Did Fail")
		refresh.delegate = delegate
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		refresh.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(refresh)
		
		waitForExpectations(timeout: 1)
		
		XCTAssertNotNil(delegate.error, "Should have failed with error.")
		if let error = delegate.error {
			switch error {
			case let error as TransportError:
				switch error {
				case .httpError(status: let status):
					XCTAssertEqual(status, 403, "Expected 403 Forbidden.")
				default:
					XCTFail("Expected 403 Forbidden")
				}
			default:
				XCTFail("Expected \(TransportError.httpError(status: 403))")
			}
		}
	}
	
	func testRefreshTokenSuccess() {
		let service = TestRefreshTokenService()
		service.refreshAccessTokenExpectation = expectation(description: "Did Call Refresh")
		
		let mockAccessToken = Credentials(type: .oauthAccessToken, username: "Test", secret: UUID().uuidString)
		let mockRefreshToken = Credentials(type: .oauthRefreshToken, username: "Test", secret: UUID().uuidString)
		let grant = OAuthAuthorizationGrant(accessToken: mockAccessToken, refreshToken: mockRefreshToken)
		service.mockResult = .success(grant)
		
		let client = support.makeMockOAuthClient()
		service.parameterTester = { serviceRefreshToken, serviceClient in
			if let accountRefreshToken = try! self.account.retrieveCredentials(type: .oauthRefreshToken) {
				XCTAssertEqual(serviceRefreshToken, accountRefreshToken.secret)
			} else {
				XCTFail("Could not verify correct refresh token used.")
			}
			XCTAssertEqual(serviceClient, client)
		}
		
		let refresh = FeedlyRefreshAccessTokenOperation(account: account, service: service, oauthClient: client, log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		refresh.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(refresh)
				
		waitForExpectations(timeout: 1)
		
		do {
			let accessToken = try account.retrieveCredentials(type: .oauthAccessToken)
			XCTAssertEqual(accessToken, mockAccessToken)
			
			let refreshToken = try account.retrieveCredentials(type: .oauthRefreshToken)
			XCTAssertEqual(refreshToken, mockRefreshToken)
		} catch {
			XCTFail("Could not verify refresh and access tokens because \(error).")
		}
	}
	
	func testRefreshTokenFailure() {
		let accessTokenBefore: Credentials
		let refreshTokenBefore: Credentials
		
		do {
			guard let accessToken = try account.retrieveCredentials(type: .oauthAccessToken),
				let refreshToken = try account.retrieveCredentials(type: .oauthRefreshToken) else {
				XCTFail("Initial refresh and/or access token does not exist.")
					return
			}
			accessTokenBefore = accessToken
			refreshTokenBefore = refreshToken
		} catch {
			XCTFail("Caught error getting initial refresh and access tokens because \(error).")
			return
		}
		
		let service = TestRefreshTokenService()
		service.refreshAccessTokenExpectation = expectation(description: "Did Call Refresh")
		service.mockResult = .failure(URLError(.timedOut))
		
		let client = support.makeMockOAuthClient()
		service.parameterTester = { serviceRefreshToken, serviceClient in
			if let accountRefreshToken = try! self.account.retrieveCredentials(type: .oauthRefreshToken) {
				XCTAssertEqual(serviceRefreshToken, accountRefreshToken.secret)
			} else {
				XCTFail("Could not verify correct refresh token used.")
			}
			XCTAssertEqual(serviceClient, client)
		}
		
		let refresh = FeedlyRefreshAccessTokenOperation(account: account, service: service, oauthClient: client, log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		refresh.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(refresh)
				
		waitForExpectations(timeout: 1)
		
		do {
			let accessToken = try account.retrieveCredentials(type: .oauthAccessToken)
			XCTAssertEqual(accessToken, accessTokenBefore)
			
			let refreshToken = try account.retrieveCredentials(type: .oauthRefreshToken)
			XCTAssertEqual(refreshToken, refreshTokenBefore)
		} catch {
			XCTFail("Could not verify refresh and access tokens because \(error).")
		}
	}
}
