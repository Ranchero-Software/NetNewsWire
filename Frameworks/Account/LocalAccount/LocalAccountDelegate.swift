//
//  LocalAccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

final class LocalAccountDelegate: AccountDelegate {

	let supportsSubFolders = false
	private let refresher = LocalAccountRefresher()
	private weak var account: Account?

	init(account: Account) {

		self.account = account
		NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressDidChange(_:)), name: .DownloadProgressDidChange, object: refresher.progress)
	}
	
	func refreshAll() {

		guard let account = account else {
			return
		}

		account.refreshInProgress = true
		refresher.refreshFeeds(account.flattenedFeeds())
	}

	// MARK: - Notifications

	@objc func downloadProgressDidChange(_ note: Notification) {

		if refresher.progress.numberRemaining < 1 {
			account?.refreshInProgress = false
		}
		else {
			account?.refreshInProgress = true
		}
	}
}
