//
//  AccountSyncError.swift
//  Account
//
//  Created by Stuart Breckenridge on 24/7/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public extension Notification.Name {
	static let AccountsDidFailToSyncWithErrors = Notification.Name("AccountsDidFailToSyncWithErrors")
}

public struct AccountSyncError: Logging {
	
	public let account: Account
	public let error: Error
	
	init(account: Account, error: Error) {
		self.account = account
		self.error = error
        AccountSyncError.logger.error("Account Sync Error: \(error.localizedDescription, privacy: .public)")
	}
	
}

