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
import FeedFinder
import RSWeb
import Secrets

@MainActor final class LocalAccountDelegate: AccountDelegate {
	weak var account: Account?

	let behaviors: AccountBehaviors = []
	let isOPMLImportInProgress = false

	var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	let server: String? = nil
	var credentials: Credentials?
	var accountSettings: AccountSettings?

	private lazy var refresher: LocalAccountRefresher = {
		let refresher = LocalAccountRefresher()
		refresher.delegate = self
		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: refresher)
		return refresher
	}()

	func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
	}

	@MainActor func refreshAll() async throws {
		guard let account else {
			return
		}
		guard progressInfo.isComplete, !Platform.isRunningUnitTests else {
			return
		}

		let feeds = account.flattenedFeeds()
		refresher.accountID = account.accountID
		await refresher.refreshFeeds(feeds)
		account.lastRefreshCompletedDate = Date()
	}

	@MainActor func syncArticleStatus() async throws -> Bool {
		false
	}

	@MainActor func sendArticleStatus() async throws {
	}

	@MainActor func refreshArticleStatus() async throws {
	}

	@MainActor func importOPML(opmlFile: URL) async throws {
		guard let account else {
			return
		}
		try account.logActivity(kind: .importOPML, detail: opmlFile.lastPathComponent) {
			let opmlData = try Data(contentsOf: opmlFile)
			let parserData = ParserData(url: opmlFile.absoluteString, data: opmlData)
			let opmlDocument = try OPMLParser.parseOPML(with: parserData)

			// TODO: throw appropriate error for empty OPML
			guard let children = opmlDocument.children else {
				return
			}

			BatchUpdate.shared.perform {
				account.loadOPMLItems(children)
			}
		}
	}

	@MainActor func createFeed(url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		guard let account else {
			throw AccountError.invalidParameter
		}
		guard let url = URL(string: urlString) else {
			throw AccountError.invalidParameter
		}

		return try await account.logActivity(kind: .subscribeFeed, detail: urlString) {
			try await createFeed(account: account, url: url, editedName: name, container: container)
		}
	}

	@MainActor func renameFeed(with feed: Feed, to name: String) async throws {
		feed.editedName = name
	}

	@MainActor func removeFeed(feed: Feed, container: Container) async throws {
		container.removeFeedFromTreeAtTopLevel(feed)
	}

	@MainActor func moveFeed(feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws {
		sourceContainer.removeFeedFromTreeAtTopLevel(feed)
		destinationContainer.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func addFeed(feed: Feed, container: Container) async throws {
		container.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func restoreFeed(feed: Feed, container: Container) async throws {
		container.addFeedToTreeAtTopLevel(feed)
	}

	@MainActor func createFolder(name: String) async throws -> Folder {
		guard let account else {
			throw AccountError.invalidParameter
		}
		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	@MainActor func renameFolder(with folder: Folder, to name: String) async throws {
		folder.name = name
	}

	@MainActor func removeFolder(with folder: Folder) async throws {
		account?.removeFolderFromTree(folder)
	}

	@MainActor func restoreFolder(folder: Folder) async throws {
		account?.addFolderToTree(folder)
	}

	@MainActor func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		_ = await account?.updateStatusesAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
	}

	func accountDidInitialize() {
	}

	func accountWillBeDeleted() {
	}

	static func validateCredentials(credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		nil
	}

	func vacuumDatabases() async {
	}

	// MARK: Suspend and Resume (for iOS)

	@MainActor func suspendNetwork() {
		refresher.suspend()
	}

	@MainActor func resume() {
		refresher.resume()
	}

	// MARK: - Notifications

	@objc func progressInfoDidChange(_ notification: Notification) {
		progressInfo = refresher.progressInfo
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
			await account.updateAsync(feed: feed, parsedFeed: parsedFeed)
		}

		return feed
	}
}
