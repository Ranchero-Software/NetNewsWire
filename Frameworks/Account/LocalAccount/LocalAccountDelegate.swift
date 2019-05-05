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
	var accountMetadata: AccountMetadata?

	private let refresher = LocalAccountRefresher()

	var refreshProgress: DownloadProgress {
		return refresher.progress
	}
	
	static func validateCredentials(transport: Transport, credentials: Credentials, completionHandler handler: (Result<Bool, Error>) -> Void) {
		return handler(.success(false))
	}

	// LocalAccountDelegate doesn't wait for completion before calling the completion block
	func refreshAll(for account: Account, completionHandler completion: (() -> Void)? = nil) {
		refresher.refreshFeeds(account.flattenedFeeds())
		completion?()
	}

	func accountDidInitialize(_ account: Account) {
	}

}
