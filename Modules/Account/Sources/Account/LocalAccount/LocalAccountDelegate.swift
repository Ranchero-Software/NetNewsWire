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

final class LocalAccountDelegate: AccountDelegate {

	weak var account: Account?

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

	lazy var refreshProgress: DownloadProgress = {
		refresher.downloadProgress
	}()

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	@MainActor func refreshAll(for account: Account) async throws {
		guard refreshProgress.isComplete, !Platform.isRunningUnitTests else {
			return
		}

		let feeds = account.flattenedFeeds()
		await refresher.refreshFeeds(feeds)
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

		return try await createFeed(account: account, url: url, editedName: name, container: container)
	}

	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		feed.editedName = name
	}

	@MainActor func removeFeed(account: Account, feed: Feed, container: Container) async throws {
		container.removeFeedFromTreeAtTopLevel(feed)
	}

	@MainActor func moveFeed(account: Account, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		sourceContainer.removeFeedFromTreeAtTopLevel(feed)
		destinationContainer.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func addFeed(account: Account, feed: Feed, container: Container) async throws {
		container.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: Container) async throws {
		container.addFeedToTreeAtTopLevel(feed)
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
		account.addFolderToTree(folder)
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

	@MainActor func suspendNetwork() {
		refresher.suspend()
	}

	@MainActor func suspendDatabase() {
		// Nothing to do
	}

	@MainActor func resume() {
		refresher.resume()
	}
}

extension LocalAccountDelegate: LocalAccountRefresherDelegate {

	func localAccountRefresher(_ refresher: LocalAccountRefresher, articleChanges: ArticleChanges) {
	}
}

private extension LocalAccountDelegate {

	@MainActor func createFeed(account: Account, url: URL, editedName: String?, container: Container) async throws -> Feed {
		// We need to use a batch update here because we need to assign add the feed to the
		// container before the name has been downloaded.  This will put it in the sidebar
		// with an Untitled name if we don't delay it being added to the sidebar.
		BatchUpdate.shared.start()
		defer {
			BatchUpdate.shared.end()
		}

		let feedSpecifiers = try await FeedFinder.find(url: url)

		guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers),
			  let url = URL(string: bestFeedSpecifier.urlString) else {
			throw AccountError.createErrorNotFound
		}

		guard !account.hasFeed(withURL: bestFeedSpecifier.urlString) else {
			throw AccountError.createErrorAlreadySubscribed
		}

		let (parsedFeed, response) = try await InitialFeedDownloader.download(url)
		guard let parsedFeed else {
			throw AccountError.createErrorNotFound
		}

		let feed = account.createFeed(with: nil, url: url.absoluteString, feedID: url.absoluteString, homePageURL: nil)
		feed.lastCheckDate = Date()

		// Save conditional GET info so that first refresh uses conditional GET.
		if let httpResponse = response as? HTTPURLResponse,
		   let conditionalGetInfo = HTTPConditionalGetInfo(urlResponse: httpResponse) {
			feed.conditionalGetInfo = conditionalGetInfo
		}

		feed.editedName = editedName
		container.addFeedToTreeAtTopLevel(feed)

		Task {
			try? await account.update(feed, with: parsedFeed)
		}

		return feed
	}
}
