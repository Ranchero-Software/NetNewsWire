//
//  AccountSyncError.swift
//  Account
//
//  Created by Stuart Breckenridge on 24/7/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log

public extension Notification.Name {
	static let AccountsDidFailToSyncWithErrors = Notification.Name("AccountsDidFailToSyncWithErrors")
}

public struct AccountSyncError {
	
	private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Application")
	public let account: Account
	public let error: Error
	
	init(account: Account, error: Error) {
		self.account = account
		self.error = error
		os_log(.error, log: AccountSyncError.log, "%@", error.localizedDescription)
	}
	
}

