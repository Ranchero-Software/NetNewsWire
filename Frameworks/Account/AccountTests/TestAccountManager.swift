//
//  TestAccountManager.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

@testable import Account

class TestAccountManager {
	
	static let shared = TestAccountManager()
	
	var accountsFolder: URL {
		return FileManager.default.temporaryDirectory

	}
	
	func createAccount(type: AccountType, username: String? = nil, password: String? = nil, transport: Transport) -> Account {
		
		let accountID = UUID().uuidString
		let accountFolder = accountsFolder.appendingPathComponent("\(type.rawValue)_\(accountID)").absoluteString
		
		do {
			try FileManager.default.createDirectory(atPath: accountFolder, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for \(accountID) account.")
			abort()
		}
		
		let account = Account(dataFolder: accountFolder, type: type, accountID: accountID, transport: transport)!
		
		return account
		
	}
	
	func deleteAccount(_ account: Account) {
		
		do {
			try FileManager.default.removeItem(atPath: account.dataFolder)
		}
		catch {
			assertionFailure("Could not create folder for OnMyMac account.")
			abort()
		}
		
	}
	
}
