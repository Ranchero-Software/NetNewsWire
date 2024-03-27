//
//  LocalAccountDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSParser
import Articles
import ArticlesDatabase
import RSWeb
import Secrets
import Core

public enum LocalAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class LocalAccountDelegate: AccountDelegate {

	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "LocalAccount")

	weak var account: Account?
	
	private lazy var refresher: LocalAccountRefresher = {
		let refresher = LocalAccountRefresher()
		refresher.delegate = self
		return refresher
	}()
	
	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false
	
	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	let refreshProgress = DownloadProgress(numberOfTasks: 0)
	
	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}
	
	func refreshAll(for account: Account) async throws {

		guard refreshProgress.isComplete else {
			return
		}

		let feeds = account.flattenedFeeds()
		refreshProgress.addToNumberOfTasksAndRemaining(feeds.count)

		await refresher.refreshFeeds(feeds)

		self.refreshProgress.clear()
		account.metadata.lastArticleFetchEndTime = Date()
	}

	func syncArticleStatus(for account: Account) async throws {
	}
	
	func sendArticleStatus(for account: Account) async throws {
	}
	
	func refreshArticleStatus(for account: Account) async throws {
	}
	
	func importOPML(for account:Account, opmlFile: URL) async throws {

		let opmlData = try Data(contentsOf: opmlFile)
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)

		let opmlDocument = try RSOPMLParser.parseOPML(with: parserData)
		guard let children = opmlDocument.children else {
			return
		}

		BatchUpdate.shared.perform {
			account.loadOPMLItems(children)
		}
	}

	func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		guard let url = URL(string: urlString) else {
			completion(.failure(LocalAccountDelegateError.invalidParameter))
			return
		}
		
        createRSSFeed(for: account, url: url, editedName: name, container: container, completion: completion)
	}

	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		feed.editedName = name
		completion(.success(()))
	}

	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.removeFeed(feed)
		completion(.success(()))
	}
	
	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		from.removeFeed(feed)
		to.addFeed(feed)
		completion(.success(()))
	}
	
	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addFeed(feed)
		completion(.success(()))
	}
	
	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addFeed(feed)
		completion(.success(()))
	}
	
	func createFolder(for account: Account, name: String) async throws -> Folder {

		guard let folder = account.ensureFolder(with: name) else {
			throw LocalAccountDelegateError.invalidParameter
		}
		return folder
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		folder.name = name
		completion(.success(()))
	}
	
	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		account.removeFolder(folder)
		completion(.success(()))
	}
	
	func restoreFolder(for account: Account, folder: Folder) async throws {
		account.addFolder(folder)
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		try await withCheckedThrowingContinuation { continuation in
			account.update(articles, statusKey: statusKey, flag: flag) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
	}
	
	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		return nil
	}

	// MARK: Suspend and Resume (for iOS)

	func suspendNetwork() {
		refresher.suspend()
	}

	func suspendDatabase() {
		// Nothing to do
	}
	
	func resume() {
		refresher.resume()
	}
}

extension LocalAccountDelegate: LocalAccountRefresherDelegate {
	
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, requestCompletedFor: Feed) {
		refreshProgress.completeTask()
	}
	
	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges, completion: @escaping () -> Void) {
		completion()
	}

}

private extension LocalAccountDelegate {
	
	func createRSSFeed(for account: Account, url: URL, editedName: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {

		Task { @MainActor in
			// We need to use a batch update here because we need to assign add the feed to the
			// container before the name has been downloaded.  This will put it in the sidebar
			// with an Untitled name if we don't delay it being added to the sidebar.
			BatchUpdate.shared.start()
			refreshProgress.addToNumberOfTasksAndRemaining(1)
			FeedFinder.find(url: url) { result in
				
				MainActor.assumeIsolated {
					switch result {
					case .success(let feedSpecifiers):
						guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
							  let url = URL(string: bestFeedSpecifier.urlString) else {
							self.refreshProgress.completeTask()
							BatchUpdate.shared.end()
							completion(.failure(AccountError.createErrorNotFound))
							return
						}
						
						if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
							self.refreshProgress.completeTask()
							BatchUpdate.shared.end()
							completion(.failure(AccountError.createErrorAlreadySubscribed))
							return
						}
						
						InitialFeedDownloader.download(url) { parsedFeed in
							self.refreshProgress.completeTask()
							
							if let parsedFeed = parsedFeed {
								let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
								feed.editedName = editedName
								container.addFeed(feed)
								
								account.update(feed, with: parsedFeed, {_ in
									MainActor.assumeIsolated {
										BatchUpdate.shared.end()
										completion(.success(feed))
									}
								})
							} else {
								BatchUpdate.shared.end()
								completion(.failure(AccountError.createErrorNotFound))
							}
							
						}
						
					case .failure:
						BatchUpdate.shared.end()
						self.refreshProgress.completeTask()
						completion(.failure(AccountError.createErrorNotFound))
					}
				}
			}
		}
	}
}
