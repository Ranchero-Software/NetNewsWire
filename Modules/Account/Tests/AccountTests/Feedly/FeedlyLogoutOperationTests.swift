//
//  FeedlyLogoutOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 15/11/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import Secrets

//class FeedlyLogoutOperationTests: XCTestCase {
//
//	private var account: Account!
//	private let support = FeedlyTestSupport()
//	
//	override func setUp() {
//		super.setUp()
//		account = support.makeTestAccount()
//	}
//	
//	override func tearDown() {
//		if let account = account {
//			support.destroy(account)
//		}
//		super.tearDown()
//	}
//	
//	private func getTokens(for account: Account) throws -> (accessToken: Credentials, refreshToken: Credentials) {
//		guard let accessToken = try account.retrieveCredentials(type: .oauthAccessToken), let refreshToken = try account.retrieveCredentials(type: .oauthRefreshToken) else {
//			XCTFail("Unable to retrieve access and/or refresh token from account.")
//			throw CredentialsError.incompleteCredentials
//		}
//		return (accessToken, refreshToken)
//	}
//	
//	class TestFeedlyLogoutService: FeedlyLogoutService {
//		var mockResult: Result<Void, Error>?
//		var logoutExpectation: XCTestExpectation?
//		
//		func logout(completion: @escaping (Result<Void, Error>) -> ()) {
//			guard let result = mockResult else {
//				XCTFail("Missing mock result. Test may time out because the completion will not be called.")
//				return
//			}
//			DispatchQueue.main.async {
//				completion(result)
//				self.logoutExpectation?.fulfill()
//			}
//		}
//	}
//	
//	func testLogoutSuccess() {
//		let service = TestFeedlyLogoutService()
//		service.logoutExpectation = expectation(description: "Did Call Logout")
//		service.mockResult = .success(())
//		
//		let logout = FeedlyLogoutOperation(account: account, service: service, log: support.log)
//		
//		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
//		let completionExpectation = expectation(description: "Did Finish")
//		logout.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(logout)
//		
//		waitForExpectations(timeout: 1)
//		
//		XCTAssertFalse(logout.isCanceled)
//		
//		do {
//			let accountAccessToken = try account.retrieveCredentials(type: .oauthAccessToken)
//			let accountRefreshToken = try account.retrieveCredentials(type: .oauthRefreshToken)
//			
//			XCTAssertNil(accountAccessToken)
//			XCTAssertNil(accountRefreshToken)
//		} catch {
//			XCTFail("Could not verify tokens were deleted.")
//		}
//	}
//	
//	class TestLogoutDelegate: FeedlyOperationDelegate {
//		var error: Error?
//		var didFailExpectation: XCTestExpectation?
//		
//		func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
//			self.error = error
//			didFailExpectation?.fulfill()
//		}
//	}
//	
//	func testLogoutMissingAccessToken() {
//		support.removeCredentials(matching: .oauthAccessToken, from: account)
//		
//		let (_, service) = support.makeMockNetworkStack()
//		service.credentials = nil
//		
//		let logout = FeedlyLogoutOperation(account: account, service: service, log: support.log)
//		
//		let delegate = TestLogoutDelegate()
//		delegate.didFailExpectation = expectation(description: "Did Fail")
//		
//		logout.delegate = delegate
//		
//		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
//		let completionExpectation = expectation(description: "Did Finish")
//		logout.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(logout)
//		
//		waitForExpectations(timeout: 1)
//		
//		XCTAssertFalse(logout.isCanceled)
//		
//		do {
//			let accountAccessToken = try account.retrieveCredentials(type: .oauthAccessToken)			
//			XCTAssertNil(accountAccessToken)
//		} catch {
//			XCTFail("Could not verify tokens were deleted.")
//		}
//		
//		XCTAssertNotNil(delegate.error, "Should have failed with error.")
//		if let error = delegate.error {
//			switch error {
//			case CredentialsError.incompleteCredentials:
//				break
//			default:
//				XCTFail("Expected \(CredentialsError.incompleteCredentials)")
//			}
//		}
//	}
//	
//	func testLogoutFailure() {
//		let service = TestFeedlyLogoutService()
//		service.logoutExpectation = expectation(description: "Did Call Logout")
//		service.mockResult = .failure(URLError(.timedOut))
//		
//		let accessToken: Credentials
//		let refreshToken: Credentials
//		do {
//			(accessToken, refreshToken) = try getTokens(for: account)
//		} catch {
//			XCTFail("Could not retrieve credentials to verify their integrity later.")
//			return
//		}
//		
//		let logout = FeedlyLogoutOperation(account: account, service: service, log: support.log)
//		
//		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
//		let completionExpectation = expectation(description: "Did Finish")
//		logout.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(logout)
//				
//		waitForExpectations(timeout: 1)
//		
//		XCTAssertFalse(logout.isCanceled)
//		
//		do {
//			let accountAccessToken = try account.retrieveCredentials(type: .oauthAccessToken)
//			let accountRefreshToken = try account.retrieveCredentials(type: .oauthRefreshToken)
//			
//			XCTAssertEqual(accountAccessToken, accessToken)
//			XCTAssertEqual(accountRefreshToken, refreshToken)
//		} catch {
//			XCTFail("Could not verify tokens were left intact. Did the operation delete them?")
//		}
//	}
//}
