//
//  LocalAccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct LocalAccountDelegate: AccountDelegate {

	let supportsSubFolders = false
	private let refresher = LocalAccountRefresher()
	
	func refreshAll(for account: Account) {

		refresher.refreshFeeds(account.flattenedFeeds())
	}
}
