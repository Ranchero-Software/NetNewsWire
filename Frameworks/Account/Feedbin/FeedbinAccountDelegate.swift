//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class FeedbinAccountDelegate: AccountDelegate {
	
	let supportsSubFolders = false
	let server: String? = "api.feedbin.com"
	
	private let caller: FeedbinAPICaller
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}
	
	var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	init(transport: Transport) {
		caller = FeedbinAPICaller(transport: transport)
	}
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	static func validateCredentials(transport: Transport, credentials: Credentials, completionHandler handler: @escaping (Result<Bool, Error>) -> Void) {
		
		let caller = FeedbinAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials() { result in
			handler(result)
		}
		
	}
	
	func refreshAll(for account: Account) {
		
	}
	
	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveBasicCredentials()
	}
	
}
