//
//  LocalAccountDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser
import Articles
import ArticlesDatabase
import RSWeb
import Secrets

public enum LocalAccountDelegateError: String, Error {
	case invalidParameter = "An invalid parameter was used."
}

final class LocalAccountDelegate: AccountDelegate {

	weak var account: Account?

	lazy var refreshProgress: DownloadProgress = {
		refresher.downloadProgress
	}()

	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false

	let server: String? = nil
	var credentials: Credentials?
	var accountMetadata: AccountMetadata?

	private lazy var refresher: LocalAccountRefresher = {
		let refresher = LocalAccountRefresher()
		refresher.delegate = self
		return refresher
	}()

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {
		guard refreshProgress.isComplete, !Platform.isRunningUnitTests else {
			return
		}

		let feeds = account.flattenedFeeds()

		await withCheckedContinuation { continuation in
			refresher.refreshFeeds(feeds) {
				continuation.resume()
			}
		}

		account.metadata.lastArticleFetchEndTime = Date()
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
	}

	@MainActor func sendArticleStatus(for account: Account) async throws {
	}

	@MainActor func refreshArticleStatus(for account: Account) async throws {
	}

	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws {
		let opmlData = try Data(contentsOf: opmlFile)
		let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
		let opmlDocument = try RSOPMLParser.parseOPML(with: parserData)

		// TODO: throw appropriate error for empty OPML
		guard let children = opmlDocument.children else {
			return
		}

		BatchUpdate.shared.perform {
			account.loadOPMLItems(children)
		}
	}

	@MainActor func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let url = URL(string: urlString) else {
			throw AccountError.invalidParameter
		}

		return try await withCheckedThrowingContinuation { continuation in
			createFeed(for: account, url: url, editedName: name, container: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		feed.editedName = name
	}

	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.removeFeed(feed)
		completion(.success(()))
	}

	@MainActor func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {
		from.removeFeed(feed)
		to.addFeed(feed)
	}

	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		container.addFeed(feed)
		completion(.success(()))
	}

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: Container) async throws {
		container.addFeed(feed)
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		folder.name = name
	}

	@MainActor func removeFolder(for account: Account, with folder: Folder) async throws {
		account.removeFolderFromTree(folder)
	}

	@MainActor func restoreFolder(for account: Account, folder: Folder) async throws {
		account.addFolder(folder)
	}

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		try await account.update(articles, statusKey: statusKey, flag: flag)
	}

	func accountDidInitialize(_ account: Account) {
		self.account = account
	}

	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		nil
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

	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges) {
	}
}

private extension LocalAccountDelegate {

	func createFeed(for account: Account, url: URL, editedName: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {

		// We need to use a batch update here because we need to assign add the feed to the
		// container before the name has been downloaded.  This will put it in the sidebar
		// with an Untitled name if we don't delay it being added to the sidebar.
		BatchUpdate.shared.start()
		FeedFinder.find(url: url) { result in

			switch result {
			case .success(let feedSpecifiers):
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
					let url = URL(string: bestFeedSpecifier.urlString) else {
						BatchUpdate.shared.end()
						completion(.failure(AccountError.createErrorNotFound))
						return
				}

				if account.hasFeed(withURL: bestFeedSpecifier.urlString) {
					BatchUpdate.shared.end()
					completion(.failure(AccountError.createErrorAlreadySubscribed))
					return
				}

				InitialFeedDownloader.download(url) { parsedFeed, _, response, _ in

					if let parsedFeed {
						let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
						feed.lastCheckDate = Date()

						// Save conditional GET info so that first refresh uses conditional GET.
						if let httpResponse = response as? HTTPURLResponse,
						   let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse) {
							feed.conditionalGetInfo = conditionalGetInfo
						}

						feed.editedName = editedName
						container.addFeed(feed)

						account.update(feed, with: parsedFeed, {_ in
							BatchUpdate.shared.end()
							completion(.success(feed))
						})
					} else {
						BatchUpdate.shared.end()
						completion(.failure(AccountError.createErrorNotFound))
					}
				}

			case .failure:
				BatchUpdate.shared.end()
				completion(.failure(AccountError.createErrorNotFound))
			}
		}
	}
}
