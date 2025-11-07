//
//  FeedbinAccountDelegate.swift
//  Account
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Articles
import RSCore
import RSDatabase
import RSParser
import RSWeb
import SyncDatabase
import os.log
import Secrets

public enum FeedbinAccountDelegateError: String, Error {
	case invalidParameter = "There was an invalid parameter passed."
	case unknown = "An unknown error occurred."
}

final class FeedbinAccountDelegate: AccountDelegate {
	let behaviors: AccountBehaviors = [.disallowFeedCopyInRootFolder]
	let server: String? = "api.feedbin.com"
	var isOPMLImportInProgress = false
	var refreshProgress = DownloadProgress(numberOfTasks: 0)

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

	private let syncDatabase: SyncDatabase
	private let caller: FeedbinAPICaller
	private static let logger = Feedbin.logger

	init(dataFolder: String, transport: Transport?) {
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("Sync.sqlite3")
		syncDatabase = SyncDatabase(databasePath: databaseFilePath)

		if let transport {
			caller = FeedbinAPICaller(transport: transport)
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

			caller = FeedbinAPICaller(transport: URLSession(configuration: sessionConfiguration))
		}
	}

	func receiveRemoteNotification(for account: Account, userInfo: [AnyHashable : Any]) async {
	}

	@MainActor func refreshAll(for account: Account) async throws {
		refreshProgress.reset()
		refreshProgress.addToNumberOfTasksAndRemaining(5)

		do {
			try await refreshAccount(account)
			try await refreshArticlesAndStatuses(account)
		} catch {
			refreshProgress.reset()
			let wrappedError = AccountError.wrappedError(error: error, account: account)
			throw wrappedError
		}
	}

	@MainActor func syncArticleStatus(for account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
	}

	@MainActor func sendArticleStatus(for account: Account) async throws {
		Self.logger.info("Feedbin: Sending article statuses")
		defer {
			Self.logger.info("Feedbin: Finished sending article statuses")
		}

		guard let syncStatuses = try await syncDatabase.selectForProcessing() else {
			return
		}

		let createUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == false })
		try await self.sendArticleStatuses(createUnreadStatuses, apiCall: self.caller.createUnreadEntries)

		let deleteUnreadStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.read && $0.flag == true })
		try await self.sendArticleStatuses(deleteUnreadStatuses, apiCall: self.caller.deleteUnreadEntries)

		let createStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == true })
		try await self.sendArticleStatuses(createStarredStatuses, apiCall: self.caller.createStarredEntries)

		let deleteStarredStatuses = Array(syncStatuses.filter { $0.key == SyncStatus.Key.starred && $0.flag == false })
		try await self.sendArticleStatuses(deleteStarredStatuses, apiCall: self.caller.deleteStarredEntries)
	}

	@MainActor func refreshArticleStatus(for account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.refreshArticleStatus(for: account) { result in
				continuation.resume(with: result)
			}
		}
	}

	func refreshArticleStatus(for account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {

		Self.logger.info("Feedbin: Refreshing article statuses")

		let group = DispatchGroup()
		var errorOccurred = false

		group.enter()
		caller.retrieveUnreadEntries() { result in
			switch result {
			case .success(let articleIDs):
				Task { @MainActor in
					await self.syncArticleReadState(account: account, articleIDs: articleIDs)
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				Self.logger.error("Feedbin: Retrieving unread entries failed: \(error.localizedDescription)")
				group.leave()
			}

		}

		group.enter()
		caller.retrieveStarredEntries() { result in
			switch result {
			case .success(let articleIDs):
				Task { @MainActor in
					await self.syncArticleStarredState(account: account, articleIDs: articleIDs)
					group.leave()
				}
			case .failure(let error):
				errorOccurred = true
				Self.logger.error("Feedbin: Retrieving starred entries failed: \(error.localizedDescription)")
				group.leave()
			}

		}

		group.notify(queue: DispatchQueue.main) {
			Self.logger.info("Feedbin: Finished refreshing article statuses")
			if errorOccurred {
				completion(.failure(FeedbinAccountDelegateError.unknown))
			} else {
				completion(.success(()))
			}
		}
	}


	@MainActor func importOPML(for account: Account, opmlFile: URL) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.importOPML(for: account, opmlFile: opmlFile) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func importOPML(for account:Account, opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {

		var fileData: Data?

		do {
			fileData = try Data(contentsOf: opmlFile)
		} catch {
			completion(.failure(error))
			return
		}

		guard let opmlData = fileData else {
			completion(.success(()))
			return
		}

		Self.logger.info("Feedbin: Did begin importing OPML")
		isOPMLImportInProgress = true
		refreshProgress.addToNumberOfTasksAndRemaining(1)

		caller.importOPML(opmlData: opmlData) { result in
			switch result {
			case .success(let importResult):
				if importResult.complete {
					Self.logger.info("Feedbin: Finished importing OPML")
					self.refreshProgress.completeTask()
					self.isOPMLImportInProgress = false
					DispatchQueue.main.async {
						completion(.success(()))
					}
				} else {
					self.checkImportResult(opmlImportResultID: importResult.importResultID, completion: completion)
				}
			case .failure(let error):
				Self.logger.info("Feedbin: OPML import failed: \(error.localizedDescription)")
				self.refreshProgress.completeTask()
				self.isOPMLImportInProgress = false
				DispatchQueue.main.async {
					let wrappedError = AccountError.wrappedError(error: error, account: account)
					completion(.failure(wrappedError))
				}
			}
		}

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

		guard folder.hasAtLeastOneFeed() else {
			folder.name = name
			return
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.renameTag(oldName: folder.name ?? "", newName: name) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				DispatchQueue.main.async {
					self.renameFolderRelationship(for: account, fromName: folder.name ?? "", toName: name)
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

		// Feedbin uses tags and if at least one feed isn't tagged, then the folder doesn't exist on their system
		guard folder.hasAtLeastOneFeed() else {
			account.removeFolderFromTree(folder)
			completion(.success(()))
			return
		}

		let group = DispatchGroup()

		for feed in folder.topLevelFeeds {

			if feed.folderRelationship?.count ?? 0 > 1 {

				if let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
					group.enter()
					refreshProgress.addToNumberOfTasksAndRemaining(1)
					caller.deleteTagging(taggingID: feedTaggingID) { result in
						self.refreshProgress.completeTask()
						group.leave()
						switch result {
						case .success:
							DispatchQueue.main.async {
								self.clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
							}
						case .failure(let error):
							Self.logger.error("Feedbin: Remove feed error: \(error.localizedDescription)")
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
							Self.logger.error("Feedbin: Remove feed error: \(error.localizedDescription)")
						}
					}

				}

			}

		}

		group.notify(queue: DispatchQueue.main) {
			account.removeFolderFromTree(folder)
			completion(.success(()))
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

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.createSubscription(url: url) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success(let subResult):
				switch subResult {
				case .created(let subscription):
					self.createFeed(account: account, subscription: subscription, name: name, container: container, completion: completion)
				case .multipleChoice(let choices):
					self.decideBestFeedChoice(account: account, url: url, name: name, container: container, choices: choices, completion: completion)
				case .alreadySubscribed:
					DispatchQueue.main.async {
						completion(.failure(AccountError.createErrorAlreadySubscribed))
					}
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
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
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
		if feed.folderRelationship?.count ?? 0 > 1 {
			deleteTagging(for: account, with: feed, from: container, completion: completion)
		} else {
			deleteSubscription(for: account, with: feed, from: container, completion: completion)
		}
	}

	@MainActor func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container) async throws {
		try await withCheckedThrowingContinuation{ continuation in
			moveFeed(for: account, with: feed, from: from, to: to) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func moveFeed(for account: Account, with feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		if from is Account {
			addFeed(for: account, with: feed, to: to, completion: completion)
		} else {
			deleteTagging(for: account, with: feed, from: from) { result in
				switch result {
				case .success:
					self.addFeed(for: account, with: feed, to: to, completion: completion)
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	func addFeed(for account: Account, with feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {

		if let folder = container as? Folder, let feedID = Int(feed.feedID) {
			refreshProgress.addToNumberOfTasksAndRemaining(1)
			caller.createTagging(feedID: feedID, name: folder.name ?? "") { result in
				self.refreshProgress.completeTask()
				switch result {
				case .success(let taggingID):
					DispatchQueue.main.async {
						self.saveFolderRelationship(for: feed, withFolderName: folder.name ?? "", id: String(taggingID))
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

	@MainActor func restoreFeed(for account: Account, feed: Feed, container: any Container) async throws {
		try await withCheckedThrowingContinuation { continuation in
			restoreFeed(for: account, feed: feed, container: container) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func restoreFeed(for account: Account, feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {

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

	private func restoreFolder(for account: Account, folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {

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
					Self.logger.error("Feedbin: Restore folder feed error: \(error.localizedDescription)")
				}
			}

		}

		group.notify(queue: DispatchQueue.main) {
			account.addFolder(folder)
			completion(.success(()))
		}

	}

	@MainActor func markArticles(for account: Account, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		let articles = try await account.update(articles, statusKey: statusKey, flag: flag)
		let syncStatuses = Set(articles.map { article in
			SyncStatus(articleID: article.articleID, key: SyncStatus.Key(statusKey), flag: flag)
		})

		try await syncDatabase.insertStatuses(syncStatuses)
		if let count = try? await syncDatabase.selectPendingCount(), count > 100 {
			try await sendArticleStatus(for: account)
		}
	}

	func accountDidInitialize(_ account: Account) {
		credentials = try? account.retrieveCredentials(type: .basic)
	}

	func accountWillBeDeleted(_ account: Account) {
	}

	static func validateCredentials(transport: Transport, credentials: Credentials, endpoint: URL?) async throws -> Credentials? {
		let caller = FeedbinAPICaller(transport: transport)
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

// MARK: Private

private extension FeedbinAccountDelegate {

	func checkImportResult(opmlImportResultID: Int, completion: @escaping (Result<Void, Error>) -> Void) {

		DispatchQueue.main.async {

			Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { timer in

				Self.logger.info("Feedbin: Checking status of OPML import")

				self.caller.retrieveOPMLImportResult(importID: opmlImportResultID) { result in
					switch result {
					case .success(let importResult):
						if let result = importResult, result.complete {
							Self.logger.info("Feedbin: Checking status of OPML import finished successfully")
							timer.invalidate()
							self.refreshProgress.completeTask()
							self.isOPMLImportInProgress = false
							DispatchQueue.main.async {
								completion(.success(()))
							}
						}
					case .failure(let error):
						Self.logger.info("Feedbin: Import OPML check failed: \(error.localizedDescription)")
						timer.invalidate()
						self.refreshProgress.completeTask()
						self.isOPMLImportInProgress = false
						DispatchQueue.main.async {
							completion(.failure(error))
						}
					}
				}

			}

		}

	}

	func refreshAccount(_ account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			refreshAccount(account) { result in
				continuation.resume(with: result)
			}
		}
	}

	func refreshAccount(_ account: Account, completion: @escaping (Result<Void, Error>) -> Void) {

		caller.retrieveTags { result in
			switch result {
			case .success(let tags):

				self.refreshProgress.completeTask()
				self.caller.retrieveSubscriptions { result in
					switch result {
					case .success(let subscriptions):

						self.refreshProgress.completeTask()
						self.forceExpireFolderFeedRelationship(account, tags)
						self.caller.retrieveTaggings { result in
							switch result {
							case .success(let taggings):

								BatchUpdate.shared.perform {
									self.syncFolders(account, tags)
									self.syncFeeds(account, subscriptions)
									self.syncFeedFolderRelationship(account, taggings)
								}

								self.refreshProgress.completeTask()
								completion(.success(()))

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

	@MainActor func refreshArticlesAndStatuses(_ account: Account) async throws {
		try await sendArticleStatus(for: account)
		try await refreshArticleStatus(for: account)
		try await refreshArticles(account)
		try await refreshMissingArticles(account)
		refreshProgress.reset()
	}

	// This function can be deleted if Feedbin updates their taggings.json service to
	// show a change when a tag is renamed.
	func forceExpireFolderFeedRelationship(_ account: Account, _ tags: [FeedbinTag]?) {
		guard let tags = tags else { return }

		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Feedbin has a tag that we don't have a folder for.  We might not get a new
		// taggings response for it if it is a folder rename.  Force expire the tagging
		// so that we will for sure get the new tagging information.
		tags.forEach { tag in
			if !folderNames.contains(tag.name) {
				accountMetadata?.conditionalGetInfo[FeedbinAPICaller.ConditionalGetKeys.taggings] = nil
			}
		}

	}

	func syncFolders(_ account: Account, _ tags: [FeedbinTag]?) {
		guard let tags = tags else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing folders \(tags.count) tags")

		let tagNames = tags.map { $0.name }

		// Delete any folders not at Feedbin
		if let folders = account.folders {
			folders.forEach { folder in
				if !tagNames.contains(folder.name ?? "") {
					for feed in folder.topLevelFeeds {
						account.addFeed(feed)
						clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					}
					account.removeFolderFromTree(folder)
				}
			}
		}

		let folderNames: [String] =  {
			if let folders = account.folders {
				return folders.map { $0.name ?? "" }
			} else {
				return [String]()
			}
		}()

		// Make any folders Feedbin has, but we don't
		tagNames.forEach { tagName in
			if !folderNames.contains(tagName) {
				_ = account.ensureFolder(with: tagName)
			}
		}

	}

	func syncFeeds(_ account: Account, _ subscriptions: [FeedbinSubscription]?) {

		guard let subscriptions = subscriptions else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing feeds with \(subscriptions.count) subscriptions")

		let subFeedIds = subscriptions.map { String($0.feedID) }

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
				account.removeFeed(feed)
			}
		}

		// Add any feeds we don't have and update any we do
		var subscriptionsToAdd = Set<FeedbinSubscription>()
		subscriptions.forEach { subscription in

			let subFeedId = String(subscription.feedID)

			if let feed = account.existingFeed(withFeedID: subFeedId) {
				feed.name = subscription.name
				// If the name has been changed on the server remove the locally edited name
				feed.editedName = nil
				feed.homePageURL = subscription.homePageURL
				feed.externalID = String(subscription.subscriptionID)
				feed.faviconURL = subscription.jsonFeed?.favicon
				feed.iconURL = subscription.jsonFeed?.icon
			}
			else {
				subscriptionsToAdd.insert(subscription)
			}
		}

		// Actually add subscriptions all in one go, so we don’t trigger various rebuilding things that Account does.
		subscriptionsToAdd.forEach { subscription in
			let feed = account.createFeed(with: subscription.name, url: subscription.url, feedID: String(subscription.feedID), homePageURL: subscription.homePageURL)
			feed.externalID = String(subscription.subscriptionID)
			account.addFeed(feed)
		}
	}

	func syncFeedFolderRelationship(_ account: Account, _ taggings: [FeedbinTagging]?) {

		guard let taggings = taggings else { return }
		assert(Thread.isMainThread)

		Self.logger.info("Feedbin: Syncing taggings with \(taggings.count) taggings")

		// Set up some structures to make syncing easier
		let folderDict = nameToFolderDictionary(with: account.folders)
		let taggingsDict = taggings.reduce([String: [FeedbinTagging]]()) { (dict, tagging) in
			var taggedFeeds = dict
			if var taggedFeed = taggedFeeds[tagging.name] {
				taggedFeed.append(tagging)
				taggedFeeds[tagging.name] = taggedFeed
			} else {
				taggedFeeds[tagging.name] = [tagging]
			}
			return taggedFeeds
		}

		// Sync the folders
		for (folderName, groupedTaggings) in taggingsDict {

			guard let folder = folderDict[folderName] else { return }

			let taggingFeedIDs = groupedTaggings.map { String($0.feedID) }

			// Move any feeds not in the folder to the account
			for feed in folder.topLevelFeeds {
				if !taggingFeedIDs.contains(feed.feedID) {
					folder.removeFeed(feed)
					clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
					account.addFeed(feed)
				}
			}

			// Add any feeds not in the folder
			let folderFeedIds = folder.topLevelFeeds.map { $0.feedID }

			for tagging in groupedTaggings {
				let taggingFeedID = String(tagging.feedID)
				if !folderFeedIds.contains(taggingFeedID) {
					guard let feed = account.existingFeed(withFeedID: taggingFeedID) else {
						continue
					}
					saveFolderRelationship(for: feed, withFolderName: folderName, id: String(tagging.taggingID))
					folder.addFeed(feed)
				}
			}

		}

		let taggedFeedIDs = Set(taggings.map { String($0.feedID) })

		// Remove all feeds from the account container that have a tag
		for feed in account.topLevelFeeds {
			if taggedFeedIDs.contains(feed.feedID) {
				account.removeFeed(feed)
			}
		}
	}

	func nameToFolderDictionary(with folders: Set<Folder>?) -> [String: Folder] {
		guard let folders = folders else {
			return [String: Folder]()
		}

		var d = [String: Folder]()
		for folder in folders {
			let name = folder.name ?? ""
			if d[name] == nil {
				d[name] = folder
			}
		}
		return d
	}

	@MainActor func sendArticleStatuses(_ statuses: [SyncStatus], apiCall: ([Int], @escaping (Result<Void, Error>) -> Void) -> Void) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.sendArticleStatuses(statuses, apiCall: apiCall) { result in
				continuation.resume(with: result)
			}
		}
	}

	func sendArticleStatuses(_ statuses: [SyncStatus],
							 apiCall: ([Int], @escaping (Result<Void, Error>) -> Void) -> Void,
							 completion: @escaping ((Result<Void, Error>) -> Void)) {

		guard !statuses.isEmpty else {
			completion(.success(()))
			return
		}

		let group = DispatchGroup()
		var errorOccurred = false

		let articleIDs = statuses.compactMap { Int($0.articleID) }
		let articleIDGroups = articleIDs.chunked(into: 1000)
		for articleIDGroup in articleIDGroups {

			group.enter()
			apiCall(articleIDGroup) { result in
				Task { @MainActor in
					switch result {
					case .success:
						try? await self.syncDatabase.deleteSelectedForProcessing(Set(articleIDGroup.map { String($0) } ))
						group.leave()
					case .failure(let error):
						errorOccurred = true

						Self.logger.error("Feedbin: Article status sync call failed: \(error.localizedDescription)")
						try? await self.syncDatabase.resetSelectedForProcessing(Set(articleIDGroup.map { String($0) } ))
						group.leave()
					}
				}
			}

		}

		group.notify(queue: DispatchQueue.main) {
			if errorOccurred {
				completion(.failure(FeedbinAccountDelegateError.unknown))
			} else {
				completion(.success(()))
			}
		}

	}

	func renameFolderRelationship(for account: Account, fromName: String, toName: String) {
		for feed in account.flattenedFeeds() {
			if var folderRelationship = feed.folderRelationship {
				let relationship = folderRelationship[fromName]
				folderRelationship[fromName] = nil
				folderRelationship[toName] = relationship
				feed.folderRelationship = folderRelationship
			}
		}
	}

	func clearFolderRelationship(for feed: Feed, withFolderName folderName: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = nil
			feed.folderRelationship = folderRelationship
		}
	}

	func saveFolderRelationship(for feed: Feed, withFolderName folderName: String, id: String) {
		if var folderRelationship = feed.folderRelationship {
			folderRelationship[folderName] = id
			feed.folderRelationship = folderRelationship
		} else {
			feed.folderRelationship = [folderName: id]
		}
	}

	func decideBestFeedChoice(account: Account, url: String, name: String?, container: Container, choices: [FeedbinSubscriptionChoice], completion: @escaping (Result<Feed, Error>) -> Void) {
		var orderFound = 0

		let feedSpecifiers: [FeedSpecifier] = choices.map { choice in
			let source = url == choice.url ? FeedSpecifier.Source.UserEntered : FeedSpecifier.Source.HTMLLink
			orderFound = orderFound + 1
			let specifier = FeedSpecifier(title: choice.name, urlString: choice.url, source: source, orderFound: orderFound)
			return specifier
		}

		if let bestSpecifier = FeedSpecifier.bestFeed(in: Set(feedSpecifiers)) {
			createFeed(for: account, url: bestSpecifier.urlString, name: name, container: container, validateFeed: true, completion: completion)
		} else {
			DispatchQueue.main.async {
				completion(.failure(FeedbinAccountDelegateError.invalidParameter))
			}
		}
	}

	func createFeed( account: Account, subscription sub: FeedbinSubscription, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {

		DispatchQueue.main.async {

			let feed = account.createFeed(with: sub.name, url: sub.url, feedID: String(sub.feedID), homePageURL: sub.homePageURL)
			feed.externalID = String(sub.subscriptionID)
			feed.iconURL = sub.jsonFeed?.icon
			feed.faviconURL = sub.jsonFeed?.favicon

			account.addFeed(feed, to: container) { result in
				switch result {
				case .success:
					if let name = name {
						account.renameFeed(feed, to: name) { result in
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

		// refreshArticles is being reused and will clear one of the tasks for us
		refreshProgress.addToNumberOfTasksAndRemaining(4)

		// Download the initial articles
		self.caller.retrieveEntries(feedID: feed.feedID) { result in
			self.refreshProgress.completeTask()

			switch result {
			case .success(let (entries, page)):

				self.processEntries(account: account, entries: entries) { error in
					if let error = error {
						completion(.failure(error))
						return
					}

					self.refreshArticleStatus(for: account) { result in
						switch result {
						case .success:

							self.refreshArticles(account, page: page, updateFetchDate: nil) { result in
								switch result {
								case .success:

									self.refreshProgress.completeTask()
									self.refreshMissingArticles(account) { result in
										switch result {
										case .success:

											self.refreshProgress.completeTask()
											DispatchQueue.main.async {
												completion(.success(feed))
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

			case .failure(let error):
				completion(.failure(error))
			}

		}

	}

	@MainActor func refreshArticles(_ account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.refreshArticles(account) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func refreshArticles(_ account: Account, completion: @escaping VoidResultCompletionBlock) {

		Self.logger.info("Feedbin: Refreshing articles")

		caller.retrieveEntries() { result in

			switch result {
			case .success(let (entries, page, updateFetchDate, lastPageNumber)):

				if let last = lastPageNumber {
					self.refreshProgress.addToNumberOfTasksAndRemaining(last - 1)
				}

				self.processEntries(account: account, entries: entries) { error in

					self.refreshProgress.completeTask()

					if let error = error {
						completion(.failure(error))
						return
					}

					self.refreshArticles(account, page: page, updateFetchDate: updateFetchDate) { result in
						Self.logger.info("Feedbin: Finished refreshing articles")
						switch result {
						case .success:
							completion(.success(()))
						case .failure(let error):
							completion(.failure(error))
						}
					}
				}

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	@MainActor func refreshMissingArticles(_ account: Account) async throws {
		try await withCheckedThrowingContinuation { continuation in
			self.refreshMissingArticles(account) { result in
				continuation.resume(with: result)
			}
		}
	}

	private func refreshMissingArticles(_ account: Account, completion: @escaping ((Result<Void, Error>) -> Void)) {
		Self.logger.info("Feedbin: Refreshing missing articles")

		account.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate { result in

			func process(_ fetchedArticleIDs: Set<String>) {
				let group = DispatchGroup()
				var errorOccurred = false

				let articleIDs = Array(fetchedArticleIDs)
				let chunkedArticleIDs = articleIDs.chunked(into: 100)

				for chunk in chunkedArticleIDs {
					group.enter()
					self.caller.retrieveEntries(articleIDs: chunk) { result in

						switch result {
						case .success(let entries):

							self.processEntries(account: account, entries: entries) { error in
								group.leave()
								if error != nil {
									errorOccurred = true
								}
							}

						case .failure(let error):
							errorOccurred = true
							Self.logger.error("Feedbin: Refresh missing articles failed: \(error.localizedDescription)")
							group.leave()
						}
					}
				}

				group.notify(queue: DispatchQueue.main) {
					self.refreshProgress.completeTask()
					Self.logger.info("Feedbin: Finished refreshing missing articles")
					if errorOccurred {
						completion(.failure(FeedbinAccountDelegateError.unknown))
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

	func refreshArticles(_ account: Account, page: String?, updateFetchDate: Date?, completion: @escaping ((Result<Void, Error>) -> Void)) {
		guard let page = page else {
			if let lastArticleFetch = updateFetchDate {
				self.accountMetadata?.lastArticleFetchStartTime = lastArticleFetch
				self.accountMetadata?.lastArticleFetchEndTime = Date()
			}
			completion(.success(()))
			return
		}

		caller.retrieveEntries(page: page) { result in

			switch result {
			case .success(let (entries, nextPage)):

				self.processEntries(account: account, entries: entries) { error in
					self.refreshProgress.completeTask()

					if let error = error {
						completion(.failure(error))
						return
					}

					self.refreshArticles(account, page: nextPage, updateFetchDate: updateFetchDate, completion: completion)
				}

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}

	func processEntries(account: Account, entries: [FeedbinEntry]?, completion: @escaping DatabaseCompletionBlock) {
		let parsedItems = mapEntriesToParsedItems(entries: entries)
		let feedIDsAndItems = Dictionary(grouping: parsedItems, by: { item in item.feedURL } ).mapValues { Set($0) }
		account.update(feedIDsAndItems: feedIDsAndItems, defaultRead: true, completion: completion)
	}

	func mapEntriesToParsedItems(entries: [FeedbinEntry]?) -> Set<ParsedItem> {
		guard let entries = entries else {
			return Set<ParsedItem>()
		}

		let parsedItems: [ParsedItem] = entries.map { entry in
			let authors = Set([ParsedAuthor(name: entry.authorName, url: entry.jsonFeed?.jsonFeedAuthor?.url, avatarURL: entry.jsonFeed?.jsonFeedAuthor?.avatarURL, emailAddress: nil)])
			return ParsedItem(syncServiceID: String(entry.articleID), uniqueID: String(entry.articleID), feedURL: String(entry.feedID), url: entry.url, externalURL: entry.jsonFeed?.jsonFeedExternalURL, title: entry.title, language: nil, contentHTML: entry.contentHTML, contentText: nil, markdown: nil, summary: entry.summary, imageURL: nil, bannerImageURL: nil, datePublished: entry.parsedDatePublished, dateModified: nil, authors: authors, tags: nil, attachments: nil)
		}

		return Set(parsedItems)

	}

	@MainActor func syncArticleReadState(account: Account, articleIDs: [Int]?) async {
		guard let articleIDs else {
			return
		}

		do {
			guard let pendingArticleIDs = try? await syncDatabase.selectPendingReadStatusArticleIDs() else {
				return
			}

			let feedbinUnreadArticleIDs = Set(articleIDs.map { String($0) } )
			let updatableFeedbinUnreadArticleIDs = feedbinUnreadArticleIDs.subtracting(pendingArticleIDs)

			let currentUnreadArticleIDs = try await account.fetchUnreadArticleIDs()

			// Mark articles as unread
			let deltaUnreadArticleIDs = updatableFeedbinUnreadArticleIDs.subtracting(currentUnreadArticleIDs)
			try await account.markAsUnread(deltaUnreadArticleIDs)

			// Mark articles as read
			let deltaReadArticleIDs = currentUnreadArticleIDs.subtracting(updatableFeedbinUnreadArticleIDs)
			try await account.markAsRead(deltaReadArticleIDs)
		} catch {
			Self.logger.error("Feedbin: Sync Article Read Status failed: \(error.localizedDescription)")
		}
	}

	@MainActor func syncArticleStarredState(account: Account, articleIDs: [Int]?) async {
		guard let articleIDs else {
			return
		}
		
		do {
			guard let pendingArticleIDs = try? await syncDatabase.selectPendingStarredStatusArticleIDs() else {
				return
			}

			let feedbinStarredArticleIDs = Set(articleIDs.map { String($0) } )
			let updatableFeedbinStarredArticleIDs = feedbinStarredArticleIDs.subtracting(pendingArticleIDs)

			let currentStarredArticleIDs = try await account.fetchStarredArticleIDs()

			// Mark articles as starred
			let deltaStarredArticleIDs = updatableFeedbinStarredArticleIDs.subtracting(currentStarredArticleIDs)
			try await account.markAsStarred(deltaStarredArticleIDs)

			// Mark articles as unstarred
			let deltaUnstarredArticleIDs = currentStarredArticleIDs.subtracting(updatableFeedbinStarredArticleIDs)
			try await account.markAsUnstarred(deltaUnstarredArticleIDs)
		} catch {
			Self.logger.error("Feedbin: Sync Article Starred Status failed: \(error.localizedDescription)")
		}
	}

	func deleteTagging(for account: Account, with feed: Feed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {

		if let folder = container as? Folder, let feedTaggingID = feed.folderRelationship?[folder.name ?? ""] {
			refreshProgress.addToNumberOfTasksAndRemaining(1)
			caller.deleteTagging(taggingID: feedTaggingID) { result in
				self.refreshProgress.completeTask()
				switch result {
				case .success:
					DispatchQueue.main.async {
						self.clearFolderRelationship(for: feed, withFolderName: folder.name ?? "")
						folder.removeFeed(feed)
						account.addFeedIfNotInAnyFolder(feed)
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
			if let account = container as? Account {
				account.removeFeed(feed)
			}
			completion(.success(()))
		}

	}

	func deleteSubscription(for account: Account, with feed: Feed, from container: Container?, completion: @escaping (Result<Void, Error>) -> Void) {

		// This error should never happen
		guard let subscriptionID = feed.externalID else {
			completion(.failure(FeedbinAccountDelegateError.invalidParameter))
			return
		}

		func complete() {
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
		}

		refreshProgress.addToNumberOfTasksAndRemaining(1)
		caller.deleteSubscription(subscriptionID: subscriptionID) { result in
			self.refreshProgress.completeTask()
			switch result {
			case .success:
				complete()
			case .failure(let error):
				Self.logger.error("Feedbin: Unable to remove feed from Feedbin. Removing locally and continuing processing: \(error.localizedDescription)")
				complete()
			}
		}
	}
}
