//
//  AccountCredentialsTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import RSWeb
@testable import Account

class AccountCredentialsTest: XCTestCase {

	private var account: Account!
	
    override func setUp() {
		account = TestAccountManager.shared.createAccount(type: .feedbin, transport: TestTransport())
    }

    override func tearDown() {
		TestAccountManager.shared.deleteAccount(account)
    }

    func testCreateRetrieveDelete() {
		
		// Make sure any left over from failed tests are gone
		do {
			try account.removeBasicCredentials()
		} catch {
			XCTFail(error.localizedDescription)
		}

		var credentials: Credentials? = Credentials.basic(username: "maurice", password: "hardpasswd")
		
		// Store the credentials
		do {
			try account.storeCredentials(credentials!)
		} catch {
			XCTFail(error.localizedDescription)
		}
		
		// Retrieve them
		credentials = nil
		do {
			credentials = try account.retrieveBasicCredentials()
		} catch {
			XCTFail(error.localizedDescription)
		}
		
		switch credentials! {
		case .basic(let username, let password):
			XCTAssertEqual("maurice", username)
			XCTAssertEqual("hardpasswd", password)
		}
		
		// Update them
		credentials = Credentials.basic(username: "maurice", password: "easypasswd")
		do {
			try account.storeCredentials(credentials!)
		} catch {
			XCTFail(error.localizedDescription)
		}
		
		// Retrieve them again
		credentials = nil
		do {
			credentials = try account.retrieveBasicCredentials()
		} catch {
			XCTFail(error.localizedDescription)
		}

		switch credentials! {
		case .basic(let username, let password):
			XCTAssertEqual("maurice", username)
			XCTAssertEqual("easypasswd", password)
		}

		// Delete them
		do {
			try account.removeBasicCredentials()
		} catch {
			XCTFail(error.localizedDescription)
		}

		// Make sure they are gone
		do {
			try credentials = account.retrieveBasicCredentials()
		} catch {
			XCTFail(error.localizedDescription)
		}
		
		XCTAssertNil(credentials)
    }

}
