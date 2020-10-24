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

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any], completion: @escaping () -> Void)

	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void)
	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void))
	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void))
	
	func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void)
	
	func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> Void)
	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void)
	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void)

	func createWebFeed(for account: Account, url: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void)
	func renameWebFeed(for account: Account, with feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> Void)
	func addWebFeed(for account: Account, with: WebFeed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void)
	func removeWebFeed(for account: Account, with feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void)
	func moveWebFeed(for account: Account, with feed: WebFeed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void)

	func restoreWebFeed(for account: Account, feed: WebFeed, container: Container, completion: @escaping (Result<Void, Error>) -> Void)
	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void)

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool)

	// Called at the end of account’s init method.
	func accountDidInitialize(_ account: Account)
	
	func accountWillBeDeleted(_ account: Account)

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, completion: @escaping (Result<Credentials?, Error>) -> Void)

	/// Suspend all network activity
	func suspendNetwork()
	
	/// Suspend the SQLite databases
	func suspendDatabase()
	
	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume()
}
