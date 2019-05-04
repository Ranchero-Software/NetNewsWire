//
//  AccountCredentialsTest.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class AccountCredentialsTest: XCTestCase {

	private var account: Account!
	
    override func setUp() {
		account = TestAccountManager.shared.createAccount(type: .feedbin, transport: NilTransport())
    }

    override func tearDown() {
		TestAccountManager.shared.deleteAccount(account)
    }

    func testExample() {
		
    }

}
