//
//  NewsBlurAccountDelegate.swift
//  Account
//
//  Created by Anh-Quang Do on 3/9/20.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Articles
import Database
@preconcurrency import RSParser
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
	let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "NewsBlur")
	let database: SyncDatabase

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

		database = SyncDatabase(databasePath: dataFolder.appending("/DB.sqlite3"))
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	func refreshAll(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.refreshAll(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
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
											self.refreshProgress.clear()
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

	func syncArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in
			sendArticleStatus(for: account) { result in
				switch result {
				case .success:
					self.refreshArticleStatus(for: account) { result in
						switch result {
						case .success:
							continuation.resume()
						case .failure(let error):
							continuation.resume(throwing: error)
						}
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	public func sendArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.sendArticleStatus(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	private func sendArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		os_log(.debug, log: log, "Sending story statuses...")

		Task { @MainActor in

			do {
				let syncStatuses = (try await self.database.selectForProcessing()) ?? Set<SyncStatus>()

				@MainActor func processStatuses(_ syncStatuses: [SyncStatus]) {
					let createUnreadStatuses = syncStatuses.filter {
						$0.key == SyncStatus.Key.read && $0.flag == false
					}
					let deleteUnreadStatuses = syncStatuses.filter {
						$0.key == SyncStatus.Key.read && $0.flag == true
					}
					let createStarredStatuses = syncStatuses.filter {
						$0.key == SyncStatus.Key.starred && $0.flag == true
					}
					let deleteStarredStatuses = syncStatuses.filter {
						$0.key == SyncStatus.Key.starred && $0.flag == false
					}

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
						os_log(.debug, log: self.log, "Done sending article statuses.")
						if errorOccurred {
							completion(.failure(NewsBlurError.unknown))
						} else {
							completion(.success(()))
						}
					}
				}

				processStatuses(Array(syncStatuses))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func refreshArticleStatus(for account: Account) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.refreshArticleStatus(for: account) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func refreshArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		os_log(.debug, log: log, "Refreshing story statuses...")

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
				os_log(.info, log: self.log, "Retrieving unread stories failed: %@.", error.localizedDescription)
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
				os_log(.info, log: self.log, "Retrieving starred stories failed: %@.", error.localizedDescription)
				group.leave()
			}
		}

		group.notify(queue: DispatchQueue.main) {
			os_log(.debug, log: self.log, "Done refreshing article statuses.")
			if errorOccurred {
				completion(.failure(NewsBlurError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}

	func refreshStories(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		os_log(.debug, log: log, "Refreshing stories...")
		os_log(.debug, log: log, "Refreshing unread stories...")

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
		os_log(.debug, log: log, "Refreshing missing stories...")

		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in

			MainActor.assumeIsolated {
				@MainActor func process(_ fetchedHashes: Set<String>) {
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
								os_log(.error, log: self.log, "Refresh missing stories failed: %@.", error.localizedDescription)
								group.leave()
							}
						}
					}

					group.notify(queue: DispatchQueue.main) {
						self.refreshProgress.completeTask()
						os_log(.debug, log: self.log, "Done refreshing missing stories.")
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

	func importOPML(for account: Account, opmlFile: URL) async throws {
	}

	func createFolder(for account: Account, name: String) async throws -> Folder {

		try await withCheckedThrowingContinuation { continuation in

			self.createFolder(for: account, name: name) { result in
				switch result {
				case .success(let folder):
					continuation.resume(returning: folder)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
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

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.renameFolder(for: account, with: folder, to: name) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
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

	func removeFolder(for account: Account, with folder: Folder) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.removeFolder(for: account, with: folder) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
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
				account.removeFolder(folder: folder)
				completion(.success(()))
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> ()) {
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

	func renameFeed(for account: Account, with feed: Feed, to name: String) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.renameFeed(for: account, with: feed, to: name) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
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

	func addFeed(for account: Account, with feed: Feed, to container: any Container) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.addFeed(for: account, with: feed, to: container) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
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

	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> ()) {
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

	func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {

		try await withCheckedThrowingContinuation { continuation in

			self.restoreFeed(for: account, feed: feed, container: container) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
		if let existingFeed = account.existingFeed(withURL: feed.url) {
			Task { @MainActor in

				do {
					try await account.addFeed(existingFeed, to: container)
					completion(.success(()))
				} catch {
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

	func restoreFolder(for account: Account, folder: Folder) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.restoreFolder(for: account, folder: folder) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
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
							os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
						}
					}
				}
			case .failure(let error):
				os_log(.error, log: self.log, "Restore folder feed error: %@.", error.localizedDescription)
			}
		}

		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {

		try await withCheckedThrowingContinuation { continuation in
			self.markArticles(for: account, articles: articles, statusKey: statusKey, flag: flag) { result in
				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		account.update(articles, statusKey: statusKey, flag: flag) { result in
			switch result {
			case .success(let articles):
				let syncStatuses = articles.map { article in
					return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				}

				Task { @MainActor in

					try? await self.database.insertStatuses(syncStatuses)

					if let count = try? await self.database.selectPendingCount(), count > 100 {
						self.sendArticleStatus(for: account) { _ in }
					}
					completion(.success(()))
				}
			case .failure(let error):
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

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?, secretsProvider: SecretsProvider) async throws -> Credentials? {

		try await withCheckedThrowingContinuation { continuation in

			self.validateCredentials(transport: transport, credentials: credentials, endpoint: endpoint, secretsProvider: secretsProvider) { result in
				switch result {
				case .success(let credentials):
					continuation.resume(returning: credentials)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private class func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil, secretsProvider: SecretsProvider, completion: @escaping (Result<Credentials?, Error>) -> ()) {
		let caller = NewsBlurAPICaller(transport: transport)
		caller.credentials = credentials
		caller.validateCredentials() { result in
			DispatchQueue.main.async {
				completion(result)
			}
		}
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.suspend()
	}

	/// Suspend the SQLLite databases
	func suspendDatabase() {
		
		Task {
			await database.suspend()
		}
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {

		Task {
			caller.resume()
			await database.resume()
		}
	}
}
