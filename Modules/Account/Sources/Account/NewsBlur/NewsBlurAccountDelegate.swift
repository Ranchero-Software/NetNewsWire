//
//  NewsBlurAccountDelegate.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSDatabase
import RSParser
import RSWeb
import SyncDatabase
import os.log
import Secrets

final class NewsBlurAccountDelegate: AccountDelegate {
	var behaviors: AccountBehaviors = []

	var isOPMLImportInProgress: Bool = false
	var server: String? = "newsblur.com"
	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}

	var accountMetadata: AccountMetadata? = nil
	var refreshProgress = DownloadProgress(numberOfTasks: 0)

	let caller: NewsBlurAPICaller
	let syncDatabase: SyncDatabase

	static let logger = NewsBlur.logger

	init(dataFolder: String, transport: Transport?) {
		if let transport = transport {
			caller = NewsBlurAPICaller(transport: transport)
		} else {
			let sessionConfiguration = URLSessionConfiguration.default
			sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
			sessionConfiguration.timeoutIntervalForRequest = 60.0
			sessionConfiguration.httpShouldSetCookies = false
			sessionConfiguration.httpCookieAcceptPolicy = .never
			sessionConfiguration.httpMaximumConnectionsPerHost = 1
			sessionConfiguration.httpCookieStorage = nil
			sessionConfiguration.urlCache = nil

			if let userAgentHeaders = UserAgent.headers() {
				sessionConfiguration.httpAdditionalHeaders = userAgentHeaders
			}

			let session = URLSession(configuration: sessionConfiguration)
			caller = NewsBlurAPICaller(transport: session)
		}

		syncDatabase = SyncDatabase(databasePath: dataFolder.appending("/DB.sqlite3"))
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			refreshAll(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {

		refreshProgress.reset()

		self.refreshProgress.addToNumberOfTasksAndRemaining(4)

		refreshFeeds(for: account) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				self.sendArticleStatus(for: account) { result in
					self.refreshProgress.completeTask()

					switch result {
					case .success:
						self.refreshArticleStatus(for: account) { result in
							self.refreshProgress.completeTask()

							switch result {
							case .success:
								self.refreshMissingStories(for: account) { result in
									self.refreshProgress.completeTask()

									switch result {
									case .success:
										DispatchQueue.main.async {
											completion(.success(()))
										}

									case .failure(let error):
										DispatchQueue.main.async {
											self.refreshProgress.reset()
											let wrappedError = AccountError.wrappedError(error: error, account: account)
											completion(.failure(wrappedError))
										}
									}
								}

							case .failure(let error):
								completion(.failure(error))
							}
						}

					case .failure(let error):
						completion(.failure(error))
					}
				}

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	@MainActor func sendArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			sendArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func sendArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		Task { @MainActor in
			Self.logger.info("NewsBlur: Sending story statuses")

			do {
				guard let syncStatuses = try await syncDatabase.selectForProcessing() else {
					completion(.success(()))
					return
				}

				let createUnreadStatuses = Array(syncStatuses.filter {
					$0.key == SyncStatus.Key.read && $0.flag == false
				})
				let deleteUnreadStatuses = Array(syncStatuses.filter {
					$0.key == SyncStatus.Key.read && $0.flag == true
				})
				let createStarredStatuses = Array(syncStatuses.filter {
					$0.key == SyncStatus.Key.starred && $0.flag == true
				})
				let deleteStarredStatuses = Array(syncStatuses.filter {
					$0.key == SyncStatus.Key.starred && $0.flag == false
				})

				let group = DispatchGroup()
				var errorOccurred = false

				group.enter()
				self.sendStoryStatuses(createUnreadStatuses, throttle: true, apiCall: self.caller.markAsUnread) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.enter()
				self.sendStoryStatuses(deleteUnreadStatuses, throttle: false, apiCall: self.caller.markAsRead) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.enter()
				self.sendStoryStatuses(createStarredStatuses, throttle: true, apiCall: self.caller.star) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.enter()
				self.sendStoryStatuses(deleteStarredStatuses, throttle: true, apiCall: self.caller.unstar) { result in
					group.leave()
					if case .failure = result {
						errorOccurred = true
					}
				}

				group.notify(queue: DispatchQueue.main) {
					Self.logger.info("NewsBlur: Finished sending article statuses")
					if errorOccurred {
						completion(.failure(NewsBlurError.unknown))
					} else {
						completion(.success(()))
					}
				}
			} catch {
				completion(.failure(error))
			}
		}
	}

	@MainActor func refreshArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			refreshArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	func refreshArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		Self.logger.info("NewsBlur: Refreshing story statuses")

		let group = DispatchGroup()
		var errorOccurred = false

		group.enter()
		caller.retrieveUnreadStoryHashes { result in
			switch result {
			case .success(let storyHashes):
				self.syncStoryReadState(account: account, hashes: storyHashes) {
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				Self.logger.error("NewsBlur: error retrieving unread stories: \(error.localizedDescription)")
				group.leave()
			}
		}

		group.enter()
		caller.retrieveStarredStoryHashes { result in
			switch result {
			case .success(let storyHashes):
				self.syncStoryStarredState(account: account, hashes: storyHashes) {
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				Self.logger.error("NewsBlur: error retrieving starred stories: \(error.localizedDescription)")
				group.leave()
			}
		}

		group.notify(queue: DispatchQueue.main) {
			Self.logger.info("NewsBlur: Finished refreshing article statuses")
			if errorOccurred {
				completion(.failure(NewsBlurError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}

	func refreshStories(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		Self.logger.info("NewsBlur: Refreshing stories and unread stories")

		caller.retrieveUnreadStoryHashes { result in
			switch result {
			case .success(let storyHashes):

				if let count = storyHashes?.count, count > 0 {
					self.refreshProgress.addToNumberOfTasksAndRemaining((count - 1) / 100 + 1)
				}

				self.refreshUnreadStories(for: account, hashes: storyHashes, updateFetchDate: nil, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func refreshMissingStories(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		Self.logger.info("NewsBlur: Refreshing missing stories")

		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in

			func process(_ fetchedHashes: Set<String>) {
				let group = DispatchGroup()
				var errorOccurred = false

				let storyHashes = Array(fetchedHashes).map {
					NewsBlurStoryHash(hash: $0, timestamp: Date())
				}
				let chunkedStoryHashes = storyHashes.chunked(into: 100)

				for chunk in chunkedStoryHashes {
					group.enter()
					self.caller.retrieveStories(hashes: chunk) { result in

						switch result {
						case .success((let stories, _)):
							self.processStories(account: account, stories: stories) { result in
								group.leave()
								if case .failure = result {
									errorOccurred = true
								}
							}
						case .failure(let error):
							errorOccurred = true
							Self.logger.error("NewsBlur: Refresh missing stories failed: \(error.localizedDescription)")
							group.leave()
						}
					}
				}

				group.notify(queue: DispatchQueue.main) {
					self.refreshProgress.completeTask()
					Self.logger.info("NewsBlur: Finished refreshing missing stories.")
					if errorOccurred {
						completion(.failure(NewsBlurError.unknown))
					} else {
						completion(.success(()))
					}
				}
			}

			switch result {
			case .success(let fetchedArticleIDs):
				process(fetchedArticleIDs)
			case .failure(let error):
				self.refreshProgress.completeTask()
				completion(.failure(error))
			}
		}
	}

	func processStories(account: Account, stories: [NewsBlurStory]?, since: Date? = nil, completion: @escaping (Result<Bool, DatabaseError>) -> Void) {
		let parsedItems = mapStoriesToParsedItems(stories: stories).filter {
			guard let datePublished = $0.datePublished, let since = since else {
				return true
			}

			return datePublished >= since
		}
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL }).mapValues {
			Set($0)
		}

		account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true) { error in
			if let error = error {
				completion(.failure(error))
				return
			}

			completion(.success(!feedIDsAndItems.isEmpty))
		}
	}

	func importOPML(for account: Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> ()) {
		completion(.success(()))
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		try await withCheckedThrowingContinuation { continuation in
			self.createFolder(for: account, name: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func createFolder(for account: Account, name: String, completion: @escaping (Result<Folder, Error>) -> ()) {
		self.refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.addFolder(named: name) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success():
				if let folder = account.ensureFolder(with: name) {
					completion(.success(folder))
				} else {
					completion(.failure(NewsBlurError.invalidParameter))
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		try await withCheckedThrowingContinuation { continuation in
			renameFolder(for: account, with: folder, to: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folderToRename = folder.name else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		let nameBefore = folder.name

		caller.renameFolder(with: folderToRename, to: name) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				completion(.success(()))
			case .failure(let error):
				folder.name = nameBefore
				completion(.failure(error))
			}
		}

		folder.name = name
	}

	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folderToRemove = folder.name else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		var feedIDs: [String] = []
		for feed in folder.topLevelFeeds {
			if (feed.folderRelationship?.count ?? 0) > 1 {
				clearFolderRelationship(for: feed, withFolderName: folderToRemove)
			} else if let feedID = feed.externalID {
				feedIDs.append(feedID)
			}
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.removeFolder(named: folderToRemove, feedIDs: feedIDs) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				account.removeFolder(folder)
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	@MainActor func createFeed(for account: Account, url urlString: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed {
		try await withCheckedThrowingContinuation { continuation in
			createFeed(for: account, url: urlString, name: name, container: container, validateFeed: validateFeed) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> ()) {
		refreshProgress.addToNumberOfTasksAndRemaining(1)

		let folderName = (container as? Folder)?.name
		caller.addURL(url, folder: folderName) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success(let feed):
				self.createFeed(account: account, feed: feed, name: name, container: container, completion: completion)
			case .failure(let error):
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
		}
	}

	@MainActor func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {
		try await withCheckedThrowingContinuation { continuation in
			renameFeed(for: account, with: feed, to: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let feedID = feed.externalID else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.renameFeed(feedID: feedID, newName: name) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				DispatchQueue.main.async {
					feed.editedName = name
					completion(.success(()))
				}

			case .failure(let error):
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
		}
	}

	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folder = container as? Folder else {
			DispatchQueue.main.async {
				if let account = container as? Account {
					account.addFeed(feed)
				}
				completion(.success(()))
			}

			return
		}

		let folderName = folder.name ?? ""
		saveFolderRelationship(for: feed, withFolderName: folderName, id: folderName)
		folder.addFeed(feed)

		completion(.success(()))
	}

	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		deleteFeed(for: account, with: feed, from: container, completion: completion)
	}

	@MainActor func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {
		try await withCheckedThrowingContinuation{ continuation in
			moveFeed(for: account, with: feed, from: from, to: to) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let feedID = feed.externalID else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.moveFeed(
				feedID: feedID,
				from: (from as? Folder)?.name,
				to: (to as? Folder)?.name
		) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success:
				from.removeFeed(feed)
				to.addFeed(feed)

				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {
		try await withCheckedThrowingContinuation { continuation in
			restoreFeed(for: account, feed: feed, container: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		if let existingFeed = account.existingFeed(withURL: feed.url) {
			account.addFeed(existingFeed, to: container) { result in
				switch result {
				case .success:
					completion(.success(()))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		} else {
			createFeed(for: account, url: feed.url, name: feed.editedName, container: container, validateFeed: true) { result in
				switch result {
				case .success:
					completion(.success(()))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	@MainActor func restoreFolder(for account: Account, folder: Folder) async throws {
		try await withCheckedThrowingContinuation { continuation in
			restoreFolder(for: account, folder: folder) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
		guard let folderName = folder.name else {
			completion(.failure(NewsBlurError.invalidParameter))
			return
		}

		var feedsToRestore: [Feed] = []
		for feed in folder.topLevelFeeds {
			feedsToRestore.append(feed)
			folder.topLevelFeeds.remove(feed)
		}

		let group = DispatchGroup()

		group.enter()
		createFolder(for: account, name: folderName) { result in
			group.leave()
			switch result {
			case .success(let folder):
				for feed in feedsToRestore {
					group.enter()
					self.restoreFeed(for: account, feed: feed, container: folder) { result in
						group.leave()
						switch result {
						case .success:
							break
						case .failure(let error):
							Self.logger.error("NewsBlur: Restore folder feed error: \(error.localizedDescription)")
						}
					}
				}
			case .failure(let error):
				Self.logger.error("NewsBlur: Restore folder feed error: \(error.localizedDescription)")
			}
		}

		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await account.update(articles, statusKey: statusKey, flag: flag)
				let syncStatuses = Set(articles.map { article in
					return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				})

				try await syncDatabase.insertStatuses(syncStatuses)
				if let count = try await syncDatabase.selectPendingCount(), count > 100 {
					sendArticleStatus(for: account) { _ in }
				}
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .newsBlurSessionId)
	}

	func accountWillBeDeleted(_ account: Account) {
		caller.logout() { _ in }
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		let caller = NewsBlurAPICaller(transport: transport)
		caller.credentials = credentials
		return try await caller.validateCredentials()
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}

	/// Suspend the SQLLite databases
	func suspendDatabase() {
		syncDatabase.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		caller.resume()
		syncDatabase.resume()
	}
}
