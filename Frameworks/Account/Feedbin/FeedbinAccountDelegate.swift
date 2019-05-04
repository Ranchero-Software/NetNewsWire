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
	
	private let caller: FeedbinAPICaller
	
	init(transport: Transport) {
		caller = FeedbinAPICaller(transport:  transport)
	}
	
	var refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	static func validateCredentials(transport: Transport, username: String, password: String, completionHandler handler: @escaping (Result<Bool, Error>) -> Void) {
		
		let caller = FeedbinAPICaller(transport:  transport)
		caller.validateCredentials(username: username, password: password) { result in
			handler(result)
		}
		
	}
	
	func refreshAll(for account: Account) {
		
	}
	
	func accountDidInitialize(_ account: Account) {
	}
	
	// MARK: Disk
	
	func update(account: Account, withUserInfo: NSDictionary?) {
		
		
	}
	
	func userInfo(for: Account) -> NSDictionary? {
		
		return nil
	}
	
}
