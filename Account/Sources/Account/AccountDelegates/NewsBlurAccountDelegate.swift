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
import Secrets
import NewsBlur
import AccountError

final class NewsBlurAccountDelegate: AccountDelegate, Logging {

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
	let database: SyncDatabase

	init(dataFolder: String, transport: Transport?) {
		if let transport = transport {
			caller = NewsBlurAPICaller(transport: transport) { url, credentials in
				URLRequest(url: url, credentials: credentials)
			}
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
			caller = NewsBlurAPICaller(transport: session) { url, credentials in
				URLRequest(url: url, credentials: credentials)
			}
		}

		database = SyncDatabase(databaseFilePath: dataFolder.appending("/DB.sqlite3"))
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
		return
	}

	func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
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
											let wrappedError = WrappedAccountError(accountID: account.accountID, accountNameForDisplay: account.nameForDisplay, underlyingError: error)
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

	func syncArticleStatus(for account: Account, completion: ((Result<Void, Error>) -> Void)? = nil) {
		sendArticleStatus(for: account) { result in
			switch result {
			case .success:
				self.refreshArticleStatus(for: account) { result in
					switch result {
					case .success:
						completion?(.success(()))
					case .failure(let error):
						completion?(.failure(error))
					}
				}
			case .failure(let error):
				completion?(.failure(error))
			}
		}
	}
	
	func sendArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
		Task { @MainActor in
			logger.debug("Sending story statuses")

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
					self.logger.debug("Done sending article statuses.")
					if errorOccurred {
						completion(.failure(NewsBlurError.unknown))
					} else {
						completion(.success(()))
					}
				}
			}

			do {
				let syncStatuses = try await database.selectForProcessing()
				processStatuses(Array(syncStatuses))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func refreshArticleStatus(for account: Account, completion: @escaping (Result<Void, Error>) -> ()) {
        logger.debug("Refreshing story statuses...")

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
                self.logger.error("Retrieving unread stories failed: \(error.localizedDescription, privacy: .public)")
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
                self.logger.error("Retrieving starred stories failed: \(error.localizedDescription, privacy: .public)")
				group.leave()
			}
		}

		group.notify(queue: DispatchQueue.main) {
            self.logger.debug("Done refreshing article statuses.")
			if errorOccurred {
				completion(.failure(NewsBlurError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}

	func refreshStories(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
        self.logger.debug("Refreshing stories...")
        self.logger.debug("Refreshing unread stories...")
        
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
        self.logger.debug("Refreshing missing stories...")

		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in

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
                            self.logger.error("Refreshing missing stories failed: \(error.localizedDescription, privacy: .public)")
							group.leave()
						}
					}
				}

				group.notify(queue: DispatchQueue.main) {
					self.refreshProgress.completeTask()
                    self.logger.debug("Done refreshing stories.")
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

	func createFolder(for account: Account, name: String) async throws -> Folder {
		self.refreshProgress.addToNumberOfTasksAndRemaining(1)

		return try await withCheckedThrowingContinuation { continuation in
			caller.addFolder(named: name) { result in
				self.refreshProgress.completeTask()

				switch result {
				case .success():
					if let folder = account.ensureFolder(with: name) {
						continuation.resume(returning: folder)
					} else {
						continuation.resume(throwing: NewsBlurError.invalidParameter)
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		guard let folderToRename = folder.name else {
			throw NewsBlurError.invalidParameter
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)

		let nameBefore = folder.name
		folder.name = name

		try await withCheckedThrowingContinuation { continuation in
			caller.renameFolder(with: folderToRename, to: name) { result in
				self.refreshProgress.completeTask()

				switch result {
				case .success:
					continuation.resume()
				case .failure(let error):
					folder.name = nameBefore
					continuation.resume(throwing: error)
				}
			}
		}
	}

	func removeFolder(for account: Account, with folder: Folder) async throws {
		guard let folderToRemove = folder.name else {
			throw NewsBlurError.invalidParameter
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

		try await withCheckedThrowingContinuation { continuation in
			caller.removeFolder(named: folderToRemove, feedIDs: feedIDs) { result in
				self.refreshProgress.completeTask()

				switch result {
				case .success:
					account.removeFolder(folder)
					continuation.resume()
				case .failure(let error):
					continuation.resume(throwing: error)
				}
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
				self.createFeed(account: account, newsBlurFeed: feed, name: name, container: container, completion: completion)
			case .failure(let error):
				DispatchQueue.main.async {
					let wrappedError = WrappedAccountError(accountID: account.accountID, accountNameForDisplay: account.nameForDisplay, underlyingError: error)
					completion(.failure(wrappedError))
				}
			}
		}
	}

    func renameFeed(for account: Account, feed: Feed, name: String) async throws {
        guard let feedID = feed.externalID else {
            throw NewsBlurError.invalidParameter
        }

        refreshProgress.addToNumberOfTasksAndRemaining(1)

        try await withCheckedThrowingContinuation { continuation in

            caller.renameFeed(feedID: feedID, newName: name) { result in
                Task { @MainActor in
                    self.refreshProgress.completeTask()

                    switch result {
                    case .success:
                        feed.editedName = name
                        continuation.resume()

                    case .failure(let error):
                        let wrappedError = WrappedAccountError(accountID: account.accountID, accountNameForDisplay: account.nameForDisplay, underlyingError: error)
                        continuation.resume(throwing: wrappedError)
                    }
                }
            }
        }
    }

	func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> ()) {
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
					let wrappedError = WrappedAccountError(accountID: account.accountID, accountNameForDisplay: account.nameForDisplay, underlyingError: error)
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

	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> ()) {
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

	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> ()) {
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

		Task { @MainActor in
			do {
				let folder = try await createFolder(for: account, name: folderName)
				for feed in feedsToRestore {
					group.enter()
					self.restoreFeed(for: account, feed: feed, container: folder) { result in
						group.leave()
						switch result {
						case .success:
							break
						case .failure(let error):
							self.logger.error("Restore folder feed error: \(error.localizedDescription, privacy: .public)")
						}
					}
				}
				group.leave()
				
			} catch {
				self.logger.error("Restore folder feed error: \(error.localizedDescription, privacy: .public)")
				group.leave()
			}
		}

		group.notify(queue: DispatchQueue.main) {
			completion(.success(()))
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		account.update(articles, statusKey: statusKey, flag: flag) { result in
			switch result {

			case .success(let articles):
				let syncStatuses = articles.map { article in
					return SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				}

				Task { @MainActor in
					do {
						try await self.database.insertStatuses(syncStatuses)
						let count = try await self.database.selectPendingCount()
						if count > 100 {
							self.sendArticleStatus(for: account) { _ in }
						}
						completion(.success(()))
					} catch {
						completion(.failure(error))
					}
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .newsBlurSessionID)
		refreshProgress.name = account.nameForDisplay
	}

	func accountWillBeDeleted(_ account: Account) {
		caller.logout() { _ in }
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL? = nil) async throws -> Credentials? {

		let caller = NewsBlurAPICaller(transport: transport) { url, credentials in
			URLRequest(url: url, credentials: credentials)
		}
		caller.credentials = credentials

		return try await withCheckedThrowingContinuation { continuation in
			caller.validateCredentials() { result in
				switch result {
				case .success(let credentials):
					continuation.resume(returning: credentials)
				case .failure(let error):
					continuation.resume(throwing: error)
				}
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
		database.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		caller.resume()
		database.resume()
	}
}
