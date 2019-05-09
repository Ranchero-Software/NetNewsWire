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
	var accountMetadata: AccountMetadata? { get set }
	
	var refreshProgress: DownloadProgress { get }

	func refreshAll(for account: Account, completion: (() -> Void)?)

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void)
	func deleteFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void)

	func createFeed(for account: Account, with name: String?, url: String, completion: @escaping (Result<AccountCreateFeedResult, Error>) -> Void)
	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void)
	func deleteFeed(for account: Account, container: Container, feed: Feed, completion: @escaping (Result<Void, Error>) -> Void)
	
	// Called at the end of account’s init method.
	func accountDidInitialize(_ account: Account)

	static func validateCredentials(transport: Transport, credentials: Credentials, completion: @escaping (Result<Bool, Error>) -> Void)
	
}
