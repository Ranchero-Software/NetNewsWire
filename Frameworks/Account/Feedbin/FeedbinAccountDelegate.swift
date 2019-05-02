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
	
	private let caller = FeedbinAPICaller()
	
	var refreshProgress: DownloadProgress {
		return DownloadProgress(numberOfTasks: 0)
	}
	
	static func validateCredentials(username: String, password: String, completionHandler handler: @escaping ((Bool) -> ())) {
		
		let caller = FeedbinAPICaller()
		caller.validateCredentials(username: username, password: password) { result in
			if result.statusCode == 200 {
				handler(true)
			} else {
				handler(false)
			}
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
