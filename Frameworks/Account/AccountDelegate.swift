//
//  AccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

public protocol AccountDelegate {

	// Local account does not; some synced accounts might.
	var supportsSubFolders: Bool { get }
	
	var refreshProgress: DownloadProgress { get }

	static func validateCredentials(username: String, password: String, completionHandler handler: @escaping ((Bool) -> ()))
	
	func refreshAll(for: Account)

	// Called at the end of account’s init method.

	func accountDidInitialize(_ account: Account)

	// Called at the end of initializing an Account using data from disk.
	// Delegate has complete control over what goes in userInfo and what it means.
	// Called even if userInfo is nil, since the delegate might have other
	// things to do at init time anyway.
	func update(account: Account, withUserInfo: NSDictionary?)

	// Saved to disk with other Account data. Could be called at any time.
	// And called many times.
	func userInfo(for: Account) -> NSDictionary?
}
