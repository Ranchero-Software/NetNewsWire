//
//  AccountCredentialsTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Web
@testable import Account
import Secrets

//class AccountCredentialsTest: XCTestCase {
//
//	private var account: Account!
//	
//    override func setUp() {
//		account = TestAccountManager.shared.createAccount(type: .feedbin, transport: TestTransport())
//    }
//
//    override func tearDown() {
//		TestAccountManager.shared.deleteAccount(account)
//    }
//
//    func testCreateRetrieveDelete() {
//		
//		// Make sure any left over from failed tests are gone
//		do {
//			try account.removeCredentials(type: .basic)
//		} catch {
//			XCTFail(error.localizedDescription)
//		}
//
//		var credentials: Credentials? = Credentials(type: .basic, username: "maurice", secret: "hardpasswd")
//		
//		// Store the credentials
//		do {
//			try account.storeCredentials(credentials!)
//		} catch {
//			XCTFail(error.localizedDescription)
//		}
//		
//		// Retrieve them
//		credentials = nil
//		do {
//			credentials = try account.retrieveCredentials(type: .basic)
//		} catch {
//			XCTFail(error.localizedDescription)
//		}
//		
//		switch credentials!.type {
//		case .basic:
//			XCTAssertEqual("maurice", credentials?.username)
//			XCTAssertEqual("hardpasswd", credentials?.secret)
//		default:
//			XCTFail("Expected \(CredentialsType.basic), received \(credentials!.type)")
//		}
//		
//		// Update them
//		credentials = Credentials(type: .basic, username: "maurice", secret: "easypasswd")
//		do {
//			try account.storeCredentials(credentials!)
//		} catch {
//			XCTFail(error.localizedDescription)
//		}
//		
//		// Retrieve them again
//		credentials = nil
//		do {
//			credentials = try account.retrieveCredentials(type: .basic)
//		} catch {
//			XCTFail(error.localizedDescription)
//		}
//
//		switch credentials!.type {
//		case .basic:
//			XCTAssertEqual("maurice", credentials?.username)
//			XCTAssertEqual("easypasswd", credentials?.secret)
//		default:
//			XCTFail("Expected \(CredentialsType.basic), received \(credentials!.type)")
//		}
//
//		// Delete them
//		do {
//			try account.removeCredentials(type: .basic)
//		} catch {
//			XCTFail(error.localizedDescription)
//		}
//
//		// Make sure they are gone
//		do {
//			try credentials = account.retrieveCredentials(type: .basic)
//		} catch {
//			XCTFail(error.localizedDescription)
//		}
//		
//		XCTAssertNil(credentials)
//    }
//
//}
