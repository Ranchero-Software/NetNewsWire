//
//  ReaderAPIAccountDelegate.swift
//  Account
//
//  Created by Jeremy Beker on 5/28/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSParser
import RSWeb
import SyncDatabase
import os.log
import Secrets

public enum ReaderAPIAccountDelegateError: LocalizedError {
	case unknown
	case invalidParameter
	case invalidResponse
	case urlNotFound

	public var errorDescription: String? {
		switch self {
		case .unknown:
			return NSLocalizedString("An unexpected error occurred.", comment: "An unexpected error occurred.")
		case .invalidParameter:
			return NSLocalizedString("An invalid parameter was passed.", comment: "An invalid parameter was passed.")
		case .invalidResponse:
			return NSLocalizedString("There was an invalid response from the server.", comment: "There was an invalid response from the server.")
		case .urlNotFound:
			return NSLocalizedString("The API URL wasn't found.", comment: "The API URL wasn't found.")
		}
	}
}

final class ReaderAPIAccountDelegate: AccountDelegate {

	private let variant: ReaderAPIVariant

	private let syncDatabase: SyncDatabase

	private let caller: ReaderAPICaller
	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ReaderAPI")

	var behaviors: AccountBehaviors {
		var behaviors: AccountBehaviors = [.disallowOPMLImports, .disallowFeedInMultipleFolders]
		if variant == .freshRSS {
			behaviors.append(.disallowFeedInRootFolder)
		}
		return behaviors
	}

	var server: String? {
		get {
			return caller.server
		}
	}

	var isOPMLImportInProgress = false

	var credentials: Credentials? {
		didSet {
			caller.credentials = credentials
		}
	}

	weak var accountMetadata: AccountMetadata? {
		didSet {
			caller.accountMetadata = accountMetadata
		}
	}

	var refreshProgress = DownloadProgress(numberOfTasks: 0)

	init(dataFolder: String, transport: Transport?, variant: ReaderAPIVariant) {
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		if transport != nil {
			caller = ReaderAPICaller(transport: transport!)
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

			caller = ReaderAPICaller(transport: URLSession(configuration: sessionConfiguration))
		}

		caller.variant = variant
		self.variant = variant
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

	private func refreshAll(for account: Account, completion: @escaping (Result<Void, Error>) -> Void) {

		refreshProgress.reset()
		refreshProgress.addToNumberOfTasksAndRemaining(6)

		refreshAccount(account) { result in
			switch result {
			case .success():
				self.sendArticleStatus(for: account) { _ in
					self.refreshProgress.completeTask()
					self.caller.retrieveItemIDs(type: .allForAccount) { result in
						self.refreshProgress.completeTask()
						switch result {
						case .success(let articleIDs):
							account.markAsRead(Set(articleIDs)) { _ in
								self.refreshArticleStatus(for: account) { _ in
									self.refreshProgress.completeTask()
									self.refreshMissingArticles(account) {
										DispatchQueue.main.async {
											self.refreshProgress.reset()
											completion(.success(()))
										}
									}
								}
							}
						case .failure(let error):
							self.refreshProgress.reset()
							completion(.failure(error))
						}
					}
				}

			case .failure(let error):
				DispatchQueue.main.async {
					self.refreshProgress.reset()

					let wrappedError = AccountError.wrappedError(error: error, account: account)
					if wrappedError.isCredentialsError, let basicCredentials = try? account.retrieveCredentials(type: .readerBasic), let endpoint = account.endpointURL {
						self.caller.credentials = basicCredentials

						self.caller.validateCredentials(endpoint: endpoint) { result in
							switch result {
							case .success(let apiCredentials):
								if let apiCredentials = apiCredentials {
									DispatchQueue.main.async {
										try? account.storeCredentials(apiCredentials)
										self.caller.credentials = apiCredentials
										self.refreshAll(for: account, completion: completion)
									}
								} else {
									DispatchQueue.main.async {
										completion(.failure(wrappedError))
									}
								}
							case .failure:
								DispatchQueue.main.async {
									completion(.failure(wrappedError))
								}
							}
						}

					} else {
						completion(.failure(wrappedError))
					}
				}
			}

		}

	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
		guard variant != .inoreader else {
			return
		}

		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	func sendArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			sendArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	func sendArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		Task { @MainActor in
			Self.logger.info("ReaderAPI: Sending article statuses")

			do {
				guard let syncStatuses = try await syncDatabase.selectForProcessing() else {
					completion(.success(()))
					return
				}

				let createUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false })
				let deleteUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true })
				let createStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true })
				let deleteStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false })

				await sendArticleStatuses(createUnreadStatuses, apiCall: caller.createUnreadEntries)
				await sendArticleStatuses(deleteUnreadStatuses, apiCall: caller.deleteUnreadEntries)
				await sendArticleStatuses(createStarredStatuses, apiCall: caller.createStarredEntries)
				await sendArticleStatuses(deleteStarredStatuses, apiCall: caller.deleteStarredEntries)

				Self.logger.info("ReaderAPI: finished sending article statuses")
				completion(.success(()))
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
	
	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		Self.logger.info("ReaderAPI: Refreshing article statuses")

		let group = DispatchGroup()
		var errorOccurred = false

		group.enter()
		caller.retrieveItemIDs(type: .unread) { result in
			switch result {
			case .success(let articleIDs):
				self.syncArticleReadState(account: account, articleIDs: articleIDs) {
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				Self.logger.error("ReaderAPI: Retrieving unread entries failed: \(error.localizedDescription)")
				group.leave()
			}

		}

		group.enter()
		caller.retrieveItemIDs(type: .starred) { result in
			switch result {
			case .success(let articleIDs):
				self.syncArticleStarredState(account: account, articleIDs: articleIDs) {
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				Self.logger.error("ReaderAPI: Retrieving starred entries failed: \(error.localizedDescription)")
				group.leave()
			}

		}

		group.notify(queue: DispatchQueue.main) {
			Self.logger.info("ReaderAPI: Finished refreshing article statuses")
			if errorOccurred {
				completion(.failure(ReaderAPIAccountDelegateError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}

	func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
	}

	@MainActor func createFolder(for account: Account, name: String) async throws -> Folder {
		guard let folder = account.ensureFolder(with: name) else {
			throw AccountError.invalidParameter
		}
		return folder
	}

	@MainActor func renameFolder(for account: Account, with folder: Folder, to name: String) async throws {
		try await withCheckedThrowingContinuation { continuation in
			renameFolder(for: account, with: folder, to: name) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func renameFolder(for account: Account, with folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.renameTag(oldName: folder.name ?? "", newName: name) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				DispatchQueue.main.async {
					folder.externalID = "user/-/label/\(name)"
					folder.name = name
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

	func removeFolder(for account: Account, with folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {

		let group = DispatchGroup()

		for feed in folder.topLevelFeeds {

			if feed.folderRelationship?.count ?? 0 > 1 {

				if let feedExternalID = feed.externalID {
					group.enter()
					refreshProgress.addToNumberOfTasksAndRemaining(1)
					caller.deleteTagging(subscriptionID: feedExternalID, tagName: folder.nameForDisplay) { result in
						self.refreshProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							DispatchQueue.main.async {
								self.clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
							}
						case .failure(let error):
							Self.logger.error("ReaderAPI: Remove feed error: \(error.localizedDescription)")
						}
					}
				}

			} else {

				if let subscriptionID = feed.externalID {
					group.enter()
					refreshProgress.addToNumberOfTasksAndRemaining(1)
					caller.deleteSubscription(subscriptionID: subscriptionID) { result in
						self.refreshProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							DispatchQueue.main.async {
								account.clearFeedMetadata(feed)
							}
						case .failure(let error):
							Self.logger.error("ReaderAPI: Remove feed error: \(error.localizedDescription)")
						}
					}
				}
			}
		}

		group.notify(queue: DispatchQueue.main) {
			if self.variant == .theOldReader {
				account.removeFolder(folder)
				completion(.success(()))
			} else {
				self.caller.deleteTag(folder: folder) { result in
					switch result {
					case .success:
						account.removeFolder(folder)
						completion(.success(()))
					case .failure(let error):
						completion(.failure(error))
					}
				}
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

	private func createFeed(for account: Account, url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		guard let url = URL(string: url) else {
			completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(2)

		FeedFinder.find(url: url) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success(let feedSpecifiers):
				let feedSpecifiers = feedSpecifiers.filter { !$0.urlString.contains("json") }
				guard let bestFeedSpecifier = FeedSpecifier.bestFeed(in: feedSpecifiers) else {
					self.refreshProgress.reset()
					completion(.failure(AccountError.createErrorNotFound))
					return
				}

				self.caller.createSubscription(url: bestFeedSpecifier.urlString, name: name, folder: container as? Folder) { result in
					self.refreshProgress.completeTask()
					switch result {
					case .success(let subResult):
						switch subResult {
						case .created(let subscription):
							self.createFeed(account: account, subscription: subscription, name: name, container: container, completion: completion)
						case .notFound:
							DispatchQueue.main.async {
								completion(.failure(AccountError.createErrorNotFound))
							}
						}
					case .failure(let error):
						DispatchQueue.main.async {
							let wrappedError = AccountError.wrappedError(error: error, account: account)
							completion(.failure(wrappedError))
						}
					}

				}
			case .failure:
				self.refreshProgress.reset()
				completion(.failure(AccountError.createErrorNotFound))
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

	private func renameFeed(for account: Account, with feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {

		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.renameSubscription(subscriptionID: subscriptionID, newName: name) { result in
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

	func removeFeed(for account: Account, with feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		guard let subscriptionID = feed.externalID else {
			completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.deleteSubscription(subscriptionID: subscriptionID) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				DispatchQueue.main.async {
					account.clearFeedMetadata(feed)
					account.removeFeed(feed)
					if let folders = account.folders {
						for folder in folders {
							folder.removeFeed(feed)
						}
					}
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

	func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if from is Account {
			addFeed(for: account, with: feed, to: to, completion: completion)
		} else {
			guard
				let subscriptionId = feed.externalID,
				let fromTag = (from as? Folder)?.name,
				let toTag = (to as? Folder)?.name
			else {
				completion(.failure(ReaderAPIAccountDelegateError.invalidParameter))
				return
			}

			refreshProgress.addToNumberOfTasksAndRemaining(1)
			caller.moveSubscription(subscriptionID: subscriptionId, fromTag: fromTag, toTag: toTag) { result in
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
	}

	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if let folder = container as? Folder, let feedExternalID = feed.externalID {
			refreshProgress.addToNumberOfTasksAndRemaining(1)
			caller.createTagging(subscriptionID: feedExternalID, tagName: folder.name ?? "") { result in
				self.refreshProgress.completeTask()
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.saveFolderRelationship(for: feed, folderExternalID: folder.externalID, feedExternalID: feedExternalID)
						account.removeFeed(feed)
						folder.addFeed(feed)
						completion(.success(()))
					}
				case .failure(let error):
					DispatchQueue.main.async {
						let wrappedError = AccountError.wrappedError(error: error, account: account)
						completion(.failure(wrappedError))
					}
				}
			}
		} else {
			DispatchQueue.main.async {
				if let account = container as? Account {
					account.addFeedIfNotInAnyFolder(feed)
				}
				completion(.success(()))
			}
		}
	}

	func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {

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

	func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {

		let group = DispatchGroup()

		for feed in folder.topLevelFeeds {

			folder.topLevelFeeds.remove(feed)

			group.enter()
			restoreFeed(for: account, feed: feed, container: folder) { result in
				group.leave()
				switch result {
				case .success:
					break
				case .failure(let error):
					Self.logger.error("ReaderAPI: Restore folder feed error: \(error.localizedDescription)")
				}
			}
		}

		group.notify(queue: DispatchQueue.main) {
			account.addFolder(folder)
			completion(.success(()))
		}
	}

	func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				let articles = try await account.update(articles, statusKey: statusKey, flag: flag)
				let syncStatuses = Set(articles.map { article in
					SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
				})

				try await syncDatabase.insertStatuses(syncStatuses)
				if let count = try await syncDatabase.selectPendingCount(), count > 100 {
					try? await sendArticleStatus(for: account)
				}

				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .readerAPIKey)
	}

	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		guard let endpoint else {
			throw TransportError.noURL
		}

		let caller = ReaderAPICaller(transport: transport)
		caller.credentials = credentials
		return try await caller.validateCredentials(endpoint: endpoint)
	}

	// MARK: Suspend and Resume (for iOS)

	/// Suspend all network activity
	func suspendNetwork() {
		caller.cancelAll()
	}

	/// Suspend the SQLLite databases
	func suspendDatabase() {
		syncDatabase.suspend()
	}

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume() {
		syncDatabase.resume()
	}
}

// MARK: Private

private extension ReaderAPIAccountDelegate {

	func refreshAccount(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {
		caller.retrieveTags { result in
			switch result {
			case .success(let tags):
				self.refreshProgress.completeTask()
				self.caller.retrieveSubscriptions { result in
					self.refreshProgress.completeTask()
					switch result {
					case .success(let subscriptions):
						BatchUpdate.shared.perform {
							self.syncFolders(account, tags)
							self.syncFeeds(account, subscriptions)
							self.syncFeedFolderRelationship(account, subscriptions)
						}
						completion(.success(()))
					case .failure(let error):
						completion(.failure(error))
					}
				}
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func syncFolders(_ account: Account, _ tags: [ReaderAPITag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		let folderTags: [ReaderAPITag]
		if variant == .inoreader {
			folderTags = tags.filter{ $0.type == "folder" }
		} else {
			folderTags = tags.filter{ $0.tagID.contains("/label/") }
		}

		guard !folderTags.isEmpty else { return }

		Self.logger.info("ReaderAPI: Syncing folders with \(folderTags.count) tags")

		let readerFolderExternalIDs = folderTags.compactMap { $0.tagID }

		// Delete any folders not at Reader
		if let folders = account.folders {
			folders.forEach { folder in
				if !readerFolderExternalIDs.contains(folder.externalID ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeed(feed)
						clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					}
					account.removeFolder(folder)
				}
			}
		}

		let folderExternalIDs: [String] =  {
			if let folders = account.folders {
				return folders.compactMap { $0.externalID }
			} else {
				return [String]()
			}
		}()

		// Make any folders Reader has, but we don't
		folderTags.forEach { tag in
			if !folderExternalIDs.contains(tag.tagID) {
				let folder = account.ensureFolder(with: tag.folderName ?? "None")
				folder?.externalID = tag.tagID
			}
		}

	}

	func syncFeeds(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {

		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		Self.logger.info("ReaderAPI: Syncing feeds with \(subscriptions.count) subscriptions")

		let subFeedIds = subscriptions.map { $0.feedID }

		// Remove any feeds that are no longer in the subscriptions
		if let folders = account.folders {
			for folder in folders {
				for feed in folder.topLevelFeeds {
					if !subFeedIds.contains(feed.feedID) {
						folder.removeFeed(feed)
					}
				}
			}
		}

		for feed in account.topLevelFeeds {
			if !subFeedIds.contains(feed.feedID) {
				account.clearFeedMetadata(feed)
				account.removeFeed(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		subscriptions.forEach { subscription in

			if let feed = account.existingFeed(withFeedID: subscription.feedID) {
				feed.name = subscription.name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
			} else {
				let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: subscription.feedID, homePageURL: subscription.homePageURL)
				feed.externalID = subscription.feedID
				account.addFeed(feed)
			}

		}

	}

	func syncFeedFolderRelationship(_ account: Account, _ subscriptions: [ReaderAPISubscription]?) {
		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)
		Self.logger.info("ReaderAPI: Syncing taggings with \(subscriptions.count) subscriptions")

		// Set up some structures to make syncing easier
		let folderDict = externalIDToFolderDictionary(with: account.folders)
		let taggingsDict = subscriptions.reduce([String: [ReaderAPISubscription]]()) { (dict, subscription) in
			var taggedFeeds = dict

			subscription.categories.forEach({ (category) in
				if var taggedFeed = taggedFeeds[category.categoryId] {
					taggedFeed.append(subscription)
					taggedFeeds[category.categoryId] = taggedFeed
				} else {
					taggedFeeds[category.categoryId] = [subscription]
				}
			})

			return taggedFeeds
		}

		// Sync the folders
		for (folderExternalID, groupedTaggings) in taggingsDict {
			guard let folder = folderDict[folderExternalID] else { return }
			let taggingFeedIDs = groupedTaggings.map { $0.feedID }

			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !taggingFeedIDs.contains(feed.feedID) {
					folder.removeFeed(feed)
					clearFolderRelationship(for: feed, folderExternalID: folder.externalID)
					account.addFeed(feed)
				}
			}

			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelFeeds.map { $0.feedID }

			for subscription in groupedTaggings {
				let taggingFeedID = subscription.feedID
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingFeed(withFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, folderExternalID: folderExternalID, feedExternalID: subscription.feedID)
					folder.addFeed(feed)
				}
			}

		}

		let taggedFeedIDs = Set(subscriptions.filter({ !$0.categories.isEmpty }).map { String($0.feedID) })

		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeed(feed)
			}
		}
	}

	func externalIDToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders = folders else {
			return [String: Folder]()
		}

		var d = [String: Folder]()

		for folder in folders {
			if let externalID = folder.externalID, d[externalID] == nil {
				d[externalID] = folder
			}
		}

		return d
	}

	func sendArticleStatuses(_ statuses: [SyncStatus], apiCall: ([String], @escaping (Result<Void, Error>) -> Void) -> Void) async {
		await withCheckedContinuation { continuation in
			sendArticleStatuses(statuses, apiCall: apiCall) {
				continuation.resume()
			}
		}
	}

	func sendArticleStatuses(_ statuses: [SyncStatus], apiCall: ([String], @escaping (Result<Void, Error>) -> Void) -> Void, completion: @escaping (() -> Void)) {
		guard !statuses.isEmpty else {
			completion()
			return
		}

		let group = DispatchGroup()

		let articleIDs = statuses.compactMap { $0.articleID }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {

			group.enter()
			apiCall(articleIDGroup) { result in
				Task { @MainActor in
					switch result {
					case .success:
						try? await self.syncDatabase.deleteSelectedForProcessing(Set(articleIDGroup.map { $0 } ))
						group.leave()
					case .failure(let error):
						Self.logger.error("ReaderAPI: Article status sync call failed: \(error.localizedDescription)")
						try? await self.syncDatabase.resetSelectedForProcessing(Set(articleIDGroup.map { $0 } ))
						group.leave()
					}
				}
			}
		}

		group.notify(queue: DispatchQueue.main) {
			completion()
		}

	}

	func clearFolderRelationship(for feed: Feed, folderExternalID: String?) {
		guard var folderRelationship = feed.folderRelationship, let folderExternalID = folderExternalID else { return }
		folderRelationship[folderExternalID] = nil
		feed.folderRelationship = folderRelationship
	}

	func saveFolderRelationship(for feed: Feed, folderExternalID: String?, feedExternalID: String) {
		guard let folderExternalID = folderExternalID else { return }
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderExternalID] = feedExternalID
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderExternalID: feedExternalID]
		}
	}

	func createFeed( account: Account, subscription sub: ReaderAPISubscription, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {

		DispatchQueue.main.async {

			let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
			feed.externalID = String(sub.feedID)

			account.addFeed(feed, to: container) { result in
				switch result {
				case .success:
					if let name = name {
						self.renameFeed(for: account, with: feed, to: name) { result in
							switch result {
							case .success:
								self.initialFeedDownload(account: account, feed: feed, completion: completion)
							case .failure(let error):
								completion(.failure(error))
							}
						}
					} else {
						self.initialFeedDownload(account: account, feed: feed, completion: completion)
					}
				case .failure(let error):
					completion(.failure(error))
				}
			}

		}

	}

	func initialFeedDownload( account: Account, feed: Feed, completion: @escaping (Result<Feed, Error>) -> Void) {
		refreshProgress.addToNumberOfTasksAndRemaining(5)

		// Download the initial articles
		self.caller.retrieveItemIDs(type: .allForFeed, feedID: feed.feedID) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success(let articleIDs):
				account.markAsRead(Set(articleIDs)) { _ in
					self.refreshProgress.completeTask()
					self.refreshArticleStatus(for: account) { _ in
						self.refreshProgress.completeTask()
						self.refreshMissingArticles(account) {
							self.refreshProgress.reset()
							DispatchQueue.main.async {
								completion(.success(feed))
							}

						}
					}

				}
			case .failure(let error):
				completion(.failure(error))
			}

		}

	}

	func refreshMissingArticles(_ account: Account, completion: @escaping VoidCompletionBlock) {
		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { articleIDsResult in

			func process(_ fetchedArticleIDs: Set<String>) {
				guard !fetchedArticleIDs.isEmpty else {
					completion()
					return
				}

				Self.logger.info("ReaderAPI: Refreshing missing articles")
				let group = DispatchGroup()

				let articleIDs = Array(fetchedArticleIDs)
				let chunkedArticleIDs = articleIDs.chunked(into: 150)

				self.refreshProgress.addToNumberOfTasksAndRemaining(chunkedArticleIDs.count - 1)

				for chunk in chunkedArticleIDs {
					group.enter()
					self.caller.retrieveEntries(articleIDs: chunk) { result in
						self.refreshProgress.completeTask()

						switch result {
						case .success(let entries):
							self.processEntries(account: account, entries: entries) {
								group.leave()
							}

						case .failure(let error):
							Self.logger.error("ReaderAPI: Refresh missing articles failed: \(error.localizedDescription)")
							group.leave()
						}
					}
				}

				group.notify(queue: DispatchQueue.main) {
					self.refreshProgress.completeTask()
					Self.logger.info("ReaderAPI: Finished refreshing missing articles")
					completion()
				}
			}

			switch articleIDsResult {
			case .success(let articleIDs):
				process(articleIDs)
			case .failure:
				self.refreshProgress.completeTask()
				completion()
			}
		}
	}

	func processEntries(account: Account, entries: [ReaderAPIEntry]?, completion: @escaping VoidCompletionBlock) {
		let parsedItems = mapEntriesToParsedItems(account: account, entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }
		account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true) { _ in
			completion()
		}
	}

	func mapEntriesToParsedItems(account: Account, entries: [ReaderAPIEntry]?) -> Set<ParsedItem> {

		guard let entries = entries else {
			return Set<ParsedItem>()
		}

		let parsedItems: [ParsedItem] = entries.compactMap { entry in
			guard let streamID = entry.origin.streamId else {
				return nil
			}

			var authors: Set<ParsedAuthor>? {
				guard let name = entry.author else {
					return nil
				}
				return Set([ParsedAuthor(name: name, url: nil, avatarURL: nil, emailAddress: nil)])
			}

			return ParsedItem(syncServiceID: entry.uniqueID(variant: variant),
							  uniqueID: entry.uniqueID(variant: variant),
							  feedURL: streamID,
							  url: nil,
							  externalURL: entry.alternates?.first?.url,
							  title: entry.title,
							  language: nil,
							  contentHTML: entry.summary.content,
							  contentText: nil,
							  markdown: nil,
							  summary: entry.summary.content,
							  imageURL: nil,
							  bannerImageURL: nil,
							  datePublished: entry.parseDatePublished(),
							  dateModified: nil,
							  authors: authors,
							  tags: nil,
							  attachments: nil)
		}

		return Set(parsedItems)

	}

	func syncArticleReadState(account: Account, articleIDs: [String]?, completion: @escaping (() -> Void)) {
		Task { @MainActor in
			guard let articleIDs else {
				completion()
				return
			}

			do {
				guard let pendingArticleIDs = try await syncDatabase.selectPendingReadStatusArticleIDs() else {
					completion()
					return
				}

				let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)
				let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDs()

				// Mark articles as unread
				let deltaUnreadArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
				try await account.markAsUnread(deltaUnreadArticleIDs)


				// Mark articles as read
				let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
				try await account.markAsRead(deltaReadArticleIDs)

				completion()
			} catch {
				Self.logger.error("ReaderAPI: Sync article read status failed: \(error.localizedDescription)")
				completion()
			}
		}
	}

	func syncArticleStarredState(account: Account, articleIDs: [String]?, completion: @escaping (() -> Void)) {
		Task { @MainActor in

			guard let articleIDs else {
				completion()
				return
			}

			do {
				guard let pendingArticleIDs = try await syncDatabase.selectPendingStarredStatusArticleIDs() else {
					completion()
					return
				}

				let updatableReaderUnreadArticleIDs = Set(articleIDs).subtracting(pendingArticleIDs)
				let currentStarredArticleIDs = try await account.fetchStarredArticleIDs()

				// Mark articles as starred
				let deltaStarredArticleIDs = updatableReaderUnreadArticleIDs.subtracting(currentStarredArticleIDs)
				try await account.markAsStarred(deltaStarredArticleIDs)

				// Mark articles as unstarred
				let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableReaderUnreadArticleIDs)
				try await account.markAsUnstarred(deltaUnstarredArticleIDs)

				completion()
			} catch {
				Self.logger.error("ReaderAPI: Sync article starred status failed: \(error.localizedDescription)")
				completion()
			}
		}
	}
}
