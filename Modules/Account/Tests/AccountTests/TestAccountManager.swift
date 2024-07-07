//
//  TestAccountManager.swift
//  AccountTests
//
//  Created by Maurice Parker on 5/4/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
@testable import Account

//final class TestAccountManager {
//
//	static let shared = TestAccountManager()
//	
//	var accountsFolder: URL {
//		return try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//
//	}
//	
//	func createAccount(type: AccountType, username: String? = nil, password: String? = nil, transport: Transport) -> Account {
//		
//		let accountID = UUID().uuidString
//		let accountFolder = accountsFolder.appendingPathComponent("\(type.rawValue)_\(accountID)")
//		
//		do {
//			try FileManager.default.createDirectory(at: accountFolder, withIntermediateDirectories: true, attributes: nil)
//		} catch {
//			assertionFailure("Could not create folder for \(accountID) account.")
//			abort()
//		}
//		
//		let account = Account(dataFolder: accountFolder.absoluteString, type: type, accountID: accountID, transport: transport)
//		
//		return account
//		
//	}
//	
//	func deleteAccount(_ account: Account) {
//		
//		do {
//			try FileManager.default.removeItem(atPath: account.dataFolder)
//		}
//		catch let error as CocoaError where error.code == .fileNoSuchFile {
//			
//		}
//		catch {
//			assertionFailure("Could not delete folder at: \(account.dataFolder) because \(error)")
//			abort()
//		}
//		
//	}
//	
//}
