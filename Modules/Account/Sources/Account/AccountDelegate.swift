//
//  AccountDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles
import RSWeb
import Secrets

protocol AccountDelegate {

	var behaviors: AccountBehaviors { get }

	var isOPMLImportInProgress: Bool { get }

	var server: String? { get }
	var credentials: Credentials? { get set }
	var accountMetadata: AccountMetadata? { get set }

	var refreshProgress: DownloadProgress { get }

	@MainActor func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async

	@MainActor func refreshAll(for account: Account) async throws
	@MainActor func syncArticleStatus(for account: Account) async throws
	@MainActor func sendArticleStatus(for account: Account) async throws
	@MainActor func refreshArticleStatus(for account: Account) async throws

	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder
	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws
	@MainActor func removeFolder(for account: Account, with folder: Folder) async throws

	@MainActor func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed
	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws
	func addFeed(for account: Account, with: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void)
	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void)
	@MainActor func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: Container) async throws
	@MainActor func restoreFolder(for account: Account, folder: Folder) async throws

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws

	// Called at the end of account’s init method.
	func accountDidInitialize(_ account: Account)

	func accountWillBeDeleted(_ account: Account)

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials?

	/// Suspend all network activity
	func suspendNetwork()

	/// Suspend the SQLite databases
	func suspendDatabase()

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume()
}
