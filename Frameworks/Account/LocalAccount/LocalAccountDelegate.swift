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
	
	// LocalAccountDelegate doesn't wait for completion before calling the completion block
	func refreshAll(for account: Account, completion: (() -> Void)? = nil) {
		refresher.refreshFeeds(account.flattenedFeeds())
		completion?()
	}

	func renameFolder(_ folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		folder.name = name
		completion(.success(()))
	}
	
	func accountDidInitialize(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, completion: (Result<Bool, Error>) -> Void) {
		return completion(.success(false))
	}
	
}
