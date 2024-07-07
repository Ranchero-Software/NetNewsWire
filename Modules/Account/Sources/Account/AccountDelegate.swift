//
//  AccountDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import Web
import Secrets

@MainActor protocol AccountDelegate {

	var behaviors: AccountBehaviors { get }

	var isOPMLImportInProgress: Bool { get }
	
	var server: String? { get }
	var credentials: Credentials? { get set }
	var accountMetadata: AccountMetadata? { get set }
	
	var refreshProgress: DownloadProgress { get }

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async

	func refreshAll(for account: Account) async throws
	func syncArticleStatus(for account: Account) async throws
	func sendArticleStatus(for account: Account) async throws
	func refreshArticleStatus(for account: Account) async throws
	
	func importOPML(for account:Account, opmlFile: URL) async throws
	
	func createFolder(for account: Account, name: String) async throws -> Folder
	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws
	func removeFolder(for account: Account, with folder: Folder) async throws

	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed
	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws
	func addFeed(for account: Account, with: Feed, to container: Container) async throws
	func removeFeed(for account: Account, with feed: Feed, from container: Container) async throws
	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws

	func restoreFeed(for account: Account, feed: Feed, container: Container) async throws
	func restoreFolder(for account: Account, folder: Folder) async throws

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws
	// Called at the end of account’s init method.
	func accountDidInitialize(_ account: Account)
	
	func accountWillBeDeleted(_ account: Account)

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials?

	/// Suspend all network activity
	func suspendNetwork()
	
	/// Suspend the SQLite databases
	func suspendDatabase()
	
	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume()
}
