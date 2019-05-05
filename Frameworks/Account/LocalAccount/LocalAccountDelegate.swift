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
	let server: String? = nil
	var credentials: Credentials?
	var settings: AccountSettings?

	private let refresher = LocalAccountRefresher()

	var refreshProgress: DownloadProgress {
		return refresher.progress
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, completionHandler handler: (Result<Bool, Error>) -> Void) {
		return handler(.success(false))
	}

	func refreshAll(for account: Account) {

		refresher.refreshFeeds(account.flattenedFeeds())
	}

	func accountDidInitialize(_ account: Account) {
	}

}
