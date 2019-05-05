//
//  AccountDelegate.swift
//  Account
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

protocol AccountDelegate {

	// Local account does not; some synced accounts might.
	var supportsSubFolders: Bool { get }
	var server: String? { get }
	var credentials: Credentials? { get set }
	var settings: AccountSettings? { get set }
	
	var refreshProgress: DownloadProgress { get }

	func refreshAll(for: Account)

	// Called at the end of account’s init method.

	func accountDidInitialize(_ account: Account)

	static func validateCredentials(transport: Transport, credentials: Credentials, completionHandler handler: @escaping (Result<Bool, Error>) -> Void)
	
}
