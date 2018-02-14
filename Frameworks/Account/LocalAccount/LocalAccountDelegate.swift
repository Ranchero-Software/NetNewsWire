//
//  LocalAccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

final class LocalAccountDelegate: AccountDelegate {

	let supportsSubFolders = false
	private let refresher = LocalAccountRefresher()

	var refreshProgress: DownloadProgress {
		return refresher.progress
	}
	
	func refreshAll(for account: Account) {

		refresher.refreshFeeds(account.flattenedFeeds())
	}

	func accountDidInitialize(_ account: Account) {

		account.nameForDisplay = NSLocalizedString("On My Mac", comment: "Local Account Name")
	}

	// MARK: Disk
	
	func update(account: Account, withUserInfo: NSDictionary?) {


	}

	func userInfo(for: Account) -> NSDictionary? {

		return nil
	}
}
