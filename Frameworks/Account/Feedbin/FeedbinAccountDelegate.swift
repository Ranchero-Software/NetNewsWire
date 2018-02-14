//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 12/10/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class FeedbinAccountDelegate: AccountDelegate {

	let supportsSubFolders = false

	var refreshProgress: DownloadProgress {
		return DownloadProgress(numberOfTasks: 0) // TODO
	}

	func refreshAll(for: Account) {

		// TODO
	}

	// MARK: Disk

	func accountDidInitialize(_ account: Account) {

		// TODO: add username to account name
		account.nameForDisplay = NSLocalizedString("Feedbin", comment: "Feedbin Account Name")
	}

	func update(account: Account, withUserInfo: NSDictionary?) {

	}

	func userInfo(for: Account) -> NSDictionary? {

		// TODO: save username
		return nil
	}
}

