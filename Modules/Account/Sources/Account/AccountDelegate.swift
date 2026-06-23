//
//  AccountDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSWeb
import Articles
import Secrets

@MainActor protocol AccountDelegate: ProgressInfoReporter {

	/// The account this delegate belongs to. Set by the account during its init,
	/// before `accountDidInitialize()` is called. Held weakly to avoid a retain
	/// cycle (the account owns its delegate strongly).
	var account: Account? { get set }

	var behaviors: AccountBehaviors { get }

	var isOPMLImportInProgress: Bool { get }

	var server: String? { get }
	var credentials: Credentials? { get set }
	var accountSettings: AccountSettings? { get set }

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async

	func refreshAll() async throws
	/// Returns `true` if any meaningful work was done (statuses sent or local
	/// statuses changed); `false` if the round was a no-op.
	func syncArticleStatus() async throws -> Bool
	func sendArticleStatus() async throws
	func refreshArticleStatus() async throws

	func importOPML(opmlFile: URL) async throws

	func createFolder(name: String) async throws -> Folder
	func renameFolder(with folder: Folder, to name: String) async throws
	func removeFolder(with folder: Folder) async throws

	func createFeed(url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed
	func renameFeed(with feed: Feed, to name: String) async throws
	func addFeed(feed: Feed, container: Container) async throws
	func removeFeed(feed: Feed, container: Container) async throws
	func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws

	func restoreFeed(feed: Feed, container: Container) async throws
	func restoreFolder(folder: Folder) async throws

	func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws

	// Called at the end of account’s init method.
	func accountDidInitialize()

	func accountWillBeDeleted()

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials?

	func vacuumDatabases() async

	/// Suspend all network activity
	func suspendNetwork()

	/// Resume network activity after a previous `suspendNetwork()`.
	func resume()
}
