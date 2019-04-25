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
	
	func restore() {
		refresher.restore()
	}
	
	func refreshAll(for account: Account, refreshMode: AccountRefreshMode) {

		refresher.refreshFeeds(account.flattenedFeeds(), refreshMode: refreshMode)
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
