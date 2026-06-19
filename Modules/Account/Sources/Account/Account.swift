//
//  Account.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

#if os(iOS)
import UIKit
#endif

import Foundation
import RSCore
import Articles
import RSParser
import RSDatabase
import ArticlesDatabase
import RSWeb
import Secrets
import ErrorLog
import ActivityLog
import os

// Main thread only.

public extension Notification.Name {
	static let UserDidAddAccount = Notification.Name("UserDidAddAccount")
	static let UserDidDeleteAccount = Notification.Name("UserDidDeleteAccount")
	static let AccountRefreshDidBegin = Notification.Name(rawValue: "AccountRefreshDidBegin")
	static let AccountRefreshDidFinish = Notification.Name(rawValue: "AccountRefreshDidFinish")
	static let AccountDidDownloadArticles = Notification.Name(rawValue: "AccountDidDownloadArticles")
	static let AccountStateDidChange = Notification.Name(rawValue: "AccountStateDidChange")
	static let StatusesDidChange = Notification.Name(rawValue: "StatusesDidChange")
	/// Posted when a delegate enqueues one or more status changes for upstream send.
	/// Distinct from `StatusesDidChange`, which also fires for remote-sourced changes.
	static let AccountDidQueueArticleStatuses = Notification.Name(rawValue: "AccountDidQueueArticleStatuses")
}

nonisolated public enum AccountType: Int, Codable, Sendable {
	// Raw values should not change since they’re stored on disk.
	case onMyMac = 1
	case cloudKit = 2
	case feedly = 16
	case feedbin = 17
	case newsBlur = 19
	case freshRSS = 20
	case inoreader = 21
	case bazQux = 22
	case theOldReader = 23

	public var isDeveloperRestricted: Bool {
		return self == .cloudKit || self == .feedbin || self == .feedly || self == .inoreader
	}

	public var displayName: String {
		switch self {
		case .onMyMac:
			return NSLocalizedString("account.name.on-my-device", tableName: "DefaultAccountNames", comment: "Device specific default account name, e.g: On My iPhone")
		// These proper names don’t have a translation.
		case .cloudKit:
			return "iCloud"
		case .feedly:
			return "Feedly"
		case .feedbin:
			return "Feedbin"
		case .newsBlur:
			return "NewsBlur"
		case .freshRSS:
			return "FreshRSS"
		case .inoreader:
			return NSLocalizedString("Inoreader", comment: "Account name")
		case .bazQux:
			return NSLocalizedString("BazQux", comment: "Account name")
		case .theOldReader:
			return NSLocalizedString("The Old Reader", comment: "Account name")
		}
	}
}

public enum FetchType {
    case starred(_: Int? = nil)
	case unread(_: Int? = nil)
	case today(_: Int? = nil)
	case folder(Folder, Bool)
	case feed(Feed)
	case articleIDs(Set<String>)
	case search(String)
	case searchWithArticleIDs(String, Set<String>)
}

@MainActor public final class Account: ProgressInfoReporter, DisplayNameProvider, UnreadCountProvider, Container, Hashable {

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Account")

    public struct UserInfoKey {
		public static let account = "account" // UserDidAddAccount, UserDidDeleteAccount
		public static let newArticles = "newArticles" // AccountDidDownloadArticles
		public static let updatedArticles = "updatedArticles" // AccountDidDownloadArticles
		public static let statuses = "statuses" // StatusesDidChange
		public static let articles = "articles" // StatusesDidChange
		public static let articleIDs = "articleIDs" // StatusesDidChange
		public static let statusKey = "statusKey" // StatusesDidChange
		public static let statusFlag = "statusFlag" // StatusesDidChange
		public static let feeds = "feeds" // AccountDidDownloadArticles, StatusesDidChange
		public static let syncErrors = "syncErrors" // AccountsDidFailToSyncWithErrors
	}

	public var isDeleted = false

	public var containerID: ContainerIdentifier? {
		ContainerIdentifier.account(accountID)
	}

	public var account: Account? {
		self
	}
	nonisolated public let accountID: String
	public let type: AccountType
	public var nameForDisplay: String {
		guard let name = name, !name.isEmpty else {
			return defaultName
		}
		return name
	}

	public var activityOwner: ActivityOwner {
		.account(accountID: accountID, displayName: nameForDisplay)
	}

	public var name: String? {
		get {
			settings.name
		}
		set {
			let currentNameForDisplay = nameForDisplay
			if newValue != settings.name {
				settings.name = newValue
				if currentNameForDisplay != nameForDisplay {
					postDisplayNameDidChangeNotification()
				}
			}
		}
	}
	public let defaultName: String

	public var isActive: Bool {
		get {
			settings.isActive
		}
		set {
			if newValue != settings.isActive {
				settings.isActive = newValue
				var userInfo = [AnyHashable: Any]()
				userInfo[UserInfoKey.account] = self
				NotificationCenter.default.post(name: .AccountStateDidChange, object: self, userInfo: userInfo)
			}
		}
	}

	public var topLevelFeeds = Set<Feed>()
	public var folders: Set<Folder>? = Set<Folder>()

	public var externalID: String? {
		get {
			settings.externalID
		}
		set {
			settings.externalID = newValue
		}
	}

	public var sortedFolders: [Folder]? {
		if let folders = folders {
			return Array(folders).sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
		}
		return nil
	}

	private var feedDictionariesNeedUpdate = true
	private var _idToFeedDictionary = [String: Feed]()
	var idToFeedDictionary: [String: Feed] {
		if feedDictionariesNeedUpdate {
			rebuildFeedDictionaries()
		}
		return _idToFeedDictionary
	}
	private var _externalIDToFeedDictionary = [String: Feed]()
	var externalIDToFeedDictionary: [String: Feed] {
		if feedDictionariesNeedUpdate {
			rebuildFeedDictionaries()
		}
		return _externalIDToFeedDictionary
	}

	var flattenedFeedURLs: Set<String> {
		Set(flattenedFeeds().map({ $0.url }))
	}

	var username: String? {
		get {
			settings.username
		}
		set {
			if newValue != settings.username {
				settings.username = newValue
			}
		}
	}

	public var lastArticleFetchStartTime: Date? {
		get {
			settings.lastArticleFetchStartTime
		}
		set {
			settings.lastArticleFetchStartTime = newValue
		}
	}

	public var lastRefreshCompletedDate: Date? {
		get {
			settings.lastRefreshCompletedDate
		}
		set {
			settings.lastRefreshCompletedDate = newValue
		}
	}

	public var endpointURL: URL? {
		get {
			settings.endpointURL
		}
		set {
			if newValue != settings.endpointURL {
				settings.endpointURL = newValue
			}
		}
	}

	private var fetchingAllUnreadCounts = false
	var areUnreadCountsInitialized = false

	public let dataFolder: String
	let database: ArticlesDatabase
	var delegate: AccountDelegate

	private var unreadCounts = [String: Int]() // [feedID: Int]

	private var _flattenedFeeds = Set<Feed>()
	private var flattenedFeedsNeedUpdate = true
	private var flattenedFeedsIDs: Set<String> {
		flattenedFeeds().feedIDs()
	}

	private lazy var opmlFile = OPMLFile(filename: (dataFolder as NSString).appendingPathComponent("Subscriptions.opml"), account: self)
	private let settings: AccountSettings
	private let feedSettingsDatabase: FeedSettingsDatabase
	private typealias FeedSettingsDictionary = [String: FeedSettings]
	private var feedSettingsCache = FeedSettingsDictionary()

    public var unreadCount = 0 {
        didSet {
            if unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }

	public var behaviors: AccountBehaviors {
		delegate.behaviors
	}

	public var refreshInProgress = false {
		didSet {
			if refreshInProgress != oldValue {
				if refreshInProgress {
					NotificationCenter.default.post(name: .AccountRefreshDidBegin, object: self)
				} else {
					NotificationCenter.default.post(name: .AccountRefreshDidFinish, object: self)
					opmlFile.markAsDirty()
				}
			}
		}
	}

	public var progressInfo = ProgressInfo() {
		didSet {
			if progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
			refreshInProgress = !progressInfo.isComplete
		}
	}

	init(dataFolder: String, type: AccountType, accountID: String) {
		switch type {
		case .onMyMac:
			self.delegate = LocalAccountDelegate()
		case .cloudKit:
			self.delegate = CloudKitAccountDelegate(dataFolder: dataFolder)
		case .feedbin:
			self.delegate = FeedbinAccountDelegate(dataFolder: dataFolder)
		case .feedly:
			self.delegate = FeedlyAccountDelegate(dataFolder: dataFolder, api: FeedlyAccountDelegate.environment)
		case .newsBlur:
			self.delegate = NewsBlurAccountDelegate(dataFolder: dataFolder)
		case .freshRSS:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, variant: .freshRSS)
		case .inoreader:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, variant: .inoreader)
		case .bazQux:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, variant: .bazQux)
		case .theOldReader:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, variant: .theOldReader)
		}

		self.accountID = accountID
		self.type = type
		self.dataFolder = dataFolder

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("DB.sqlite3")
		let retentionStyle: ArticlesDatabase.RetentionStyle = (type == .onMyMac || type == .cloudKit) ? .feedBased : .syncSystem
		self.database = ArticlesDatabase(databaseFilePath: databaseFilePath, accountID: accountID, retentionStyle: retentionStyle)

		defaultName = type.displayName

		let feedSettingsDatabasePath = (dataFolder as NSString).appendingPathComponent("FeedSettings.db")
		self.feedSettingsDatabase = FeedSettingsDatabase(databasePath: feedSettingsDatabasePath)

		self.settings = AccountSettings(accountID: accountID, dataFolder: dataFolder)

		NotificationCenter.default.addObserver(self, selector: #selector(progressInfoDidChange(_:)), name: .progressInfoDidChange, object: delegate)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(childrenDidChange(_:)), name: .ChildrenDidChange, object: nil)

		delegate.accountSettings = settings

		FeedSettingsImporter.importIfNeeded(dataFolder: dataFolder, database: feedSettingsDatabase)
		populateFeedSettingsCache()

		opmlFile.load()
		feedSettingsDatabase.deleteSettingsForFeedsNotIn(flattenedFeedURLs)

		DispatchQueue.main.async {
			self.database.cleanupDatabaseAtStartup(subscribedToFeedIDs: self.flattenedFeedsIDs)
			self._fetchAllUnreadCounts()
		}

		delegate.account = self
		delegate.accountDidInitialize()
	}

	// MARK: - Credentials

	public func storeCredentials(_ credentials: Credentials) throws {
		username = credentials.username
		guard let server = delegate.server else {
			assertionFailure()
			return
		}
		do {
			try CredentialsManager.storeCredentials(credentials, server: server)
		} catch {
			Self.logger.error("Account: storeCredentials: failed to store credentials: \(error.localizedDescription, privacy: .public)")
			postCredentialError(error, operation: "Storing credentials")
			throw error
		}
		delegate.credentials = credentials
	}

	public func retrieveCredentials(type: CredentialsType) throws -> Credentials? {
		guard let username = self.username else {
			Self.logger.error("Account: retrieveCredentials: username is nil for \(type.rawValue, privacy: .public)")
			return nil
		}
		guard let server = delegate.server else {
			Self.logger.error("Account: retrieveCredentials: delegate.server is nil for \(type.rawValue, privacy: .public)")
			return nil
		}
		do {
			return try CredentialsManager.retrieveCredentials(type: type, server: server, username: username)
		} catch {
			Self.logger.error("Account: retrieveCredentials: failed to retrieve \(type.rawValue, privacy: .public) credentials: \(error.localizedDescription, privacy: .public)")
			postCredentialError(error, operation: "Retrieving credentials")
			throw error
		}
	}

	public func removeCredentials(type: CredentialsType) throws {
		guard let username = self.username, let server = delegate.server else {
			return
		}
		do {
			try CredentialsManager.removeCredentials(type: type, server: server, username: username)
		} catch {
			Self.logger.error("Account: removeCredentials: failed to remove credentials: \(error.localizedDescription, privacy: .public)")
			postCredentialError(error, operation: "Removing credentials")
			throw error
		}
	}

	public static func validateCredentials(type: AccountType, credentials: Credentials, endpoint: URL? = nil) async throws -> Credentials? {
		try await ActivityLog.shared.logActivity(owner: .app, kind: .validateCredentials, detail: type.displayName, successMessage: { $0 == nil ? "Invalid credentials" : "Credentials valid" }, {
			switch type {
			case .feedbin:
				return try await FeedbinAccountDelegate.validateCredentials(credentials: credentials, endpoint: endpoint)
			case .newsBlur:
				return try await NewsBlurAccountDelegate.validateCredentials(credentials: credentials, endpoint: endpoint)
			case .freshRSS, .inoreader, .bazQux, .theOldReader:
				return try await ReaderAPIAccountDelegate.validateCredentials(credentials: credentials, endpoint: endpoint)
			default:
				return nil
			}
		})
	}

	nonisolated internal static func oauthAuthorizationClient(for type: AccountType) -> OAuthAuthorizationClient {
		switch type {
		case .feedly:
			return FeedlyAccountDelegate.environment.oauthAuthorizationClient
		default:
			fatalError("\(type) is not a client for OAuth authorization code granting.")
		}
	}

	public static func oauthAuthorizationCodeGrantRequest(for type: AccountType) -> URLRequest {
		let grantingType: OAuthAuthorizationGranting.Type
		switch type {
		case .feedly:
			grantingType = FeedlyAccountDelegate.self
		default:
			fatalError("\(type) does not support OAuth authorization code granting.")
		}

		return grantingType.oauthAuthorizationCodeGrantRequest()
	}

	public static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse,
	                                           client: OAuthAuthorizationClient,
	                                           accountType: AccountType) async throws -> OAuthAuthorizationGrant {
		let grantingType: OAuthAuthorizationGranting.Type

		switch accountType {
		case .feedly:
			grantingType = FeedlyAccountDelegate.self
		default:
			fatalError("\(accountType) does not support OAuth authorization code granting.")
		}

		return try await grantingType.requestOAuthAccessToken(with: response)
	}

	public func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
		await delegate.receiveRemoteNotification(userInfo: userInfo)
	}

	// MARK: - Refreshing

	/// Start a refresh session without waiting or catching errors.
	public func triggerRefreshAll() {
		Task {
			try? await refreshAll()
		}
	}

	public func refreshAll() async throws {
		try await delegate.refreshAll()
	}

	// MARK: - Activity Log

	@discardableResult
	public func logActivity<T>(
		kind: ActivityKind,
		detail: String? = nil,
		successMessage: ((T) -> String?)? = nil,
		durationIsSignificant: ((T) -> Bool)? = nil,
		_ work: () async throws -> T
	) async rethrows -> T {
		try await ActivityLog.shared.logActivity(owner: activityOwner, kind: kind, detail: detail, successMessage: successMessage, durationIsSignificant: durationIsSignificant, work)
	}

	/// Synchronous overload of `logActivity` for non-async work.
	@discardableResult
	public func logActivity<T>(
		kind: ActivityKind,
		detail: String? = nil,
		successMessage: ((T) -> String?)? = nil,
		durationIsSignificant: ((T) -> Bool)? = nil,
		_ work: () throws -> T
	) rethrows -> T {
		try ActivityLog.shared.logActivity(owner: activityOwner, kind: kind, detail: detail, successMessage: successMessage, durationIsSignificant: durationIsSignificant, work)
	}

	// MARK: - Syncing Article Status

	public func sendArticleStatus() async throws {
		try await delegate.sendArticleStatus()
	}

	@discardableResult
	public func syncArticleStatus() async throws -> Bool {
		try await delegate.syncArticleStatus()
	}

	// MARK: - OPML

	public func importOPML(_ opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
		guard !delegate.isOPMLImportInProgress else {
			completion(.failure(AccountError.opmlImportInProgress))
			return
		}

		Task { @MainActor in
			do {
				try await delegate.importOPML(opmlFile: opmlFile)
				// Reset the last fetch date to get the article history for the added feeds.
				lastArticleFetchStartTime = nil
				try? await delegate.refreshAll()
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	// MARK: - Suspend/Resume

	public func suspendNetwork() {
		delegate.suspendNetwork()
	}

	/// Resume network activity for the delegate after a previous `suspendNetwork()`.
	public func resumeDelegate() {
		delegate.resume()
	}

	/// Reload OPML, etc.
	public func resume() {
		_fetchAllUnreadCounts()
	}

	// MARK: - Data

	public func save() {
		MainActor.assumeIsolated {
			opmlFile.save()
		}
	}

	public func prepareForDeletion() {
		delegate.accountWillBeDeleted()
	}

	func deleteSettings() {
		settings.deleteSettings()
	}

	func addOPMLItems(_ items: [OPMLItem]) {
		for item in items {
			if let feedSpecifier = item.feedSpecifier {
				addFeedToTreeAtTopLevel(newFeed(with: feedSpecifier))
			} else {
				if let title = item.titleFromAttributes, let folder = ensureFolder(with: title) {
					folder.externalID = item.attributes?["nnw_externalID"]
					if let itemChildren = item.children {
						for itemChild in itemChildren {
							if let feedSpecifier = itemChild.feedSpecifier {
								folder.addFeedToTreeAtTopLevel(newFeed(with: feedSpecifier))
							}
						}
					}
				}
			}
		}
	}

	func loadOPMLItems(_ items: [OPMLItem]) {
		addOPMLItems(OPMLNormalizer.normalize(items))
	}

	public func markArticles(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async throws {
		try await delegate.markArticles(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
	}

	func existingContainer(withExternalID externalID: String) -> Container? {
		guard self.externalID != externalID else {
			return self
		}
		return existingFolder(withExternalID: externalID)
	}

	public func existingContainers(withFeed feed: Feed) -> [Container] {
		var containers = [Container]()
		if topLevelFeeds.contains(feed) {
			containers.append(self)
		}
		if let folders {
			for folder in folders {
				if folder.topLevelFeeds.contains(feed) {
					containers.append(folder)
				}
			}
		}
		return containers
	}

	@discardableResult
	func ensureFolder(with name: String) -> Folder? {
		// TODO: support subfolders, maybe, some day

		if name.isEmpty {
			return nil
		}

		if let folder = existingFolder(with: name) {
			return folder
		}

		let folder = Folder(account: self, name: name)
		folders!.insert(folder)
		structureDidChange()

		postChildrenDidChangeNotification()
		return folder
	}

	public func ensureFolder(withFolderNames folderNames: [String]) -> Folder? {
		// TODO: support subfolders, maybe, some day.
		// Since we don’t, just take the last name and make sure there’s a Folder.

		guard let folderName = folderNames.last else {
			return nil
		}
		return ensureFolder(with: folderName)
	}

	public func existingFolder(withDisplayName displayName: String) -> Folder? {
		return folders?.first(where: { $0.nameForDisplay == displayName })
	}

	public func existingFolder(withExternalID externalID: String) -> Folder? {
		return folders?.first(where: { $0.externalID == externalID })
	}

	func newFeed(with opmlFeedSpecifier: OPMLFeedSpecifier) -> Feed {
		let feedURL = opmlFeedSpecifier.feedURL
		let settings = feedSettings(feedURL: feedURL, feedID: feedURL)
		let feed = Feed(account: self, url: opmlFeedSpecifier.feedURL, settings: settings)
		if let feedTitle = opmlFeedSpecifier.title {
			if feed.name == nil {
				feed.name = feedTitle
			}
		}
		return feed
	}

	func addFeed(_ feed: Feed, container: Container) async throws {
		try await delegate.addFeed(feed: feed, container: container)
	}

	public func addFeed(_ feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await delegate.addFeed(feed: feed, container: container)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	public func createFeed(url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		Task { @MainActor in
			do {
				let feed = try await delegate.createFeed(url: url, name: name, container: container, validateFeed: validateFeed)
				completion(.success(feed))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func createFeed(with name: String?, url: String, feedID: String, homePageURL: String?) -> Feed {
		let settings = feedSettings(feedURL: url, feedID: feedID)
		let feed = Feed(account: self, url: url, settings: settings)
		feed.name = name
		feed.homePageURL = homePageURL
		return feed
	}

	func clearFeedSettings(_ feed: Feed) {
		// Call before permanently removing a feed so the next feed created at this URL
		// doesn’t inherit a stale feedID/externalID from the cache or database.
		feedSettingsCache[feed.url] = nil
		feedSettingsDatabase.deleteSettings(for: feed.url)
	}

	public func removeFeed(_ feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await delegate.removeFeed(feed: feed, container: container)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	public func moveFeed(_ feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await delegate.moveFeed(feed: feed, sourceContainer: from, destinationContainer: to)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	public func renameFeed(_ feed: Feed, name: String) async throws {
		try await delegate.renameFeed(with: feed, to: name)
	}

	public func restoreFeed(_ feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await delegate.restoreFeed(feed: feed, container: container)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	@discardableResult
	public func addFolder(_ name: String) async throws -> Folder {
		try await delegate.createFolder(name: name)
	}

	public func removeFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await delegate.removeFolder(with: folder)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	public func renameFolder(_ folder: Folder, to name: String) async throws {
		try await delegate.renameFolder(with: folder, to: name)
	}

	public func restoreFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		Task { @MainActor in
			do {
				try await delegate.restoreFolder(folder: folder)
				completion(.success(()))
			} catch {
				completion(.failure(error))
			}
		}
	}

	func addFolderToTree(_ folder: Folder) {
		folders!.insert(folder)
		postChildrenDidChangeNotification()
		structureDidChange()
	}

	public func updateUnreadCounts(feeds: Set<Feed>) {
		_fetchUnreadCounts(feeds: feeds)
	}

	// MARK: - Fetching Articles

	public func fetchArticles(_ fetchType: FetchType) -> Set<Article> {
		switch fetchType {
		case .starred(let limit):
			return _fetchStarredArticles(limit: limit)
		case .unread(let limit):
			return _fetchUnreadArticles(limit: limit)
		case .today(let limit):
			return _fetchTodayArticles(limit: limit)
		case .folder(let folder, let readFilter):
			if readFilter {
				return _fetchUnreadArticles(container: folder)
			} else {
				return _fetchArticles(container: folder)
			}
		case .feed(let feed):
			return _fetchArticles(feed: feed)
		case .articleIDs(let articleIDs):
			return _fetchArticles(articleIDs: articleIDs)
		case .search(let searchString):
			return _fetchArticlesMatching(searchString: searchString)
		case .searchWithArticleIDs(let searchString, let articleIDs):
			return _fetchArticlesMatchingWithArticleIDs(searchString: searchString, articleIDs: articleIDs)
		}
	}

	public func fetchArticlesAsync(_ fetchType: FetchType) async -> Set<Article> {
		switch fetchType {
		case .starred(let limit):
			return await _fetchStarredArticlesAsync(limit: limit)
		case .unread(let limit):
			return await _fetchUnreadArticlesAsync(limit: limit)
		case .today(let limit):
			return await _fetchTodayArticlesAsync(limit: limit)
		case .folder(let folder, let readFilter):
			if readFilter {
				return await _fetchUnreadArticlesAsync(container: folder)
			} else {
				return await _fetchArticlesAsync(container: folder)
			}
		case .feed(let feed):
			return await _fetchArticlesAsync(feed: feed)
		case .articleIDs(let articleIDs):
			return await _fetchArticlesAsync(articleIDs: articleIDs)
		case .search(let searchString):
			return await _fetchArticlesMatchingAsync(searchString: searchString)
		case .searchWithArticleIDs(let searchString, let articleIDs):
			return await _fetchArticlesMatchingWithArticleIDsAsync(searchString: searchString, articleIDs: articleIDs)
		}
	}

	public func fetchUnreadCountForStarredArticlesAsync() async -> Int {
		await database.fetchUnreadCountForStarredArticlesAsync(feedIDs: flattenedFeedsIDs)
	}

	public func fetchCountForStarredArticles() -> Int {
		database.fetchStarredArticlesCount(feedIDs: flattenedFeedsIDs)
	}

	public func fetchArticleCountsAsync() async -> ArticleCounts {
		await database.fetchArticleCountsAsync(feedIDs: flattenedFeedsIDs)
	}

	/// Returns a dictionary of feedID → latest article date for all feeds with articles.
	public func fetchLastUpdateDates() async -> [String: Date] {
		await database.fetchLastUpdateDates()
	}

	public func fetchUnreadCountForTodayAsync() async -> Int {
		await database.fetchUnreadCountForTodayAsync(feedIDs: flattenedFeedsIDs)
	}

	public func fetchCountForTodayArticlesAsync() async -> Int {
		await database.fetchTodayArticlesCountAsync(feedIDs: flattenedFeedsIDs)
	}

	public func fetchCountForStarredArticlesAsync() async -> Int {
		await database.fetchStarredArticlesCountAsync(feedIDs: flattenedFeedsIDs)
	}

	public func fetchUnreadArticleIDsAsync() async -> Set<String> {
		await database.fetchUnreadArticleIDsAsync()
	}

	public func fetchStarredArticleIDsAsync() async -> Set<String> {
		await database.fetchStarredArticleIDsAsync()
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are either (starred) or (newer than the article cutoff date).
	public func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync() async -> Set<String> {
		await database.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDateAsync()
	}

	// MARK: - Unread Counts
	public func unreadCount(for feed: Feed) -> Int {
		unreadCounts[feed.feedID] ?? 0
	}

	public func setUnreadCount(_ unreadCount: Int, for feed: Feed) {
		unreadCounts[feed.feedID] = unreadCount
	}

	public func structureDidChange() {
		// Feeds were added or deleted. Or folders added or deleted.
		// Or feeds inside folders were added or deleted.
		opmlFile.markAsDirty()
		flattenedFeedsNeedUpdate = true
		feedDictionariesNeedUpdate = true
	}

	// MARK: - Updating Feeds

	@discardableResult
	func updateAsync(feed: Feed, parsedFeed: ParsedFeed) async -> ArticleChanges {
		precondition(Thread.isMainThread)
		precondition(type == .onMyMac || type == .cloudKit)

		feed.takeSettings(from: parsedFeed)
		let parsedItems = parsedFeed.items
		guard !parsedItems.isEmpty else {
			return ArticleChanges()
		}

		return await updateAsync(feedID: feed.feedID, parsedItems: parsedItems)
	}

	func updateAsync(feedID: String, parsedItems: Set<ParsedItem>, deleteOlder: Bool = true) async -> ArticleChanges {
		// Used only by an On My Mac or iCloud account.
		precondition(Thread.isMainThread)
		precondition(type == .onMyMac || type == .cloudKit)

		let articleChanges = await database.updateAsync(parsedItems: parsedItems, feedID: feedID, deleteOlder: deleteOlder)
		sendNotificationAbout(articleChanges)
		return articleChanges
	}

	func updateAsync(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool) async {
		// Used only by syncing systems.
		precondition(Thread.isMainThread)
		precondition(type != .onMyMac && type != .cloudKit)
		guard !feedIDsAndItems.isEmpty else {
			return
		}

		let newAndUpdatedArticles = await database.updateAsync(feedIDsAndItems: feedIDsAndItems, defaultRead: defaultRead)
		sendNotificationAbout(newAndUpdatedArticles)
	}

	/// Mark statuses for articleIDs. Returns the articleIDs whose status actually changed.
	@discardableResult
	func updateStatusesAsync(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async -> Set<String> {
		guard !articleIDs.isEmpty else {
			return Set<String>()
		}

		let changedArticleIDs = await database.markAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		guard !changedArticleIDs.isEmpty else {
			return Set<String>()
		}
		noteStatusesForArticleIDsDidChange(articleIDs: changedArticleIDs, statusKey: statusKey, flag: flag)

		return changedArticleIDs
	}

	// MARK: - Article Statuses

	/// Make sure statuses exist. Any existing statuses won’t be touched.
	/// All created statuses will be marked as read and not starred.
	/// Sends a .StatusesDidChange notification.
	func createStatusesIfNeededAsync(articleIDs: Set<String>) async {
		guard !articleIDs.isEmpty else {
			return
		}
		await database.createStatusesIfNeededAsync(articleIDs: articleIDs)
		noteStatusesForArticleIDsDidChange(articleIDs)
	}

	/// Mark articleIDs statuses based on statusKey and flag.
	///
	/// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	/// Returns a set of new article statuses.
	func markAndFetchNewAsync(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) async -> Set<String> {
		guard !articleIDs.isEmpty else {
			return Set<String>()
		}

		let newArticleStatusIDs = await database.markAndFetchNewAsync(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		noteStatusesForArticleIDsDidChange(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
		return newArticleStatusIDs
	}

	/// Mark articleIDs as read.
	///
	/// - Returns: Set of new article statuses.
	/// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	@discardableResult
	func markAsReadAsync(articleIDs: Set<String>) async -> Set<String> {
		await markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .read, flag: true)
	}

	/// Mark articleIDs as unread.
	/// - Returns: Set of new article statuses.
	/// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	@discardableResult
	func markAsUnreadAsync(articleIDs: Set<String>) async -> Set<String> {
		await markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .read, flag: false)
	}

	/// Mark articleIDs as starred.
	/// - Returns: Set of new article statuses.
	/// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	@discardableResult
	func markAsStarredAsync(articleIDs: Set<String>) async -> Set<String> {
		await markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .starred, flag: true)
	}

	/// Mark articleIDs as unstarred.
	/// - Returns: Set of new article statuses.
	/// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	@discardableResult
	func markAsUnstarredAsync(articleIDs: Set<String>) async -> Set<String> {
		await markAndFetchNewAsync(articleIDs: articleIDs, statusKey: .starred, flag: false)
	}

	// Delete the articles associated with the given set of articleIDs
	func delete(articleIDs: Set<String>) async {
		guard !articleIDs.isEmpty else {
			return
		}
		await database.deleteAsync(articleIDs: articleIDs)
	}

	/// Empty caches that can reasonably be emptied. Call when the app goes in the background, for instance.
	func emptyCaches() {
		database.emptyCaches()
	}

	// MARK: - Container

	public func flattenedFeeds() -> Set<Feed> {
		assert(Thread.isMainThread)
		if flattenedFeedsNeedUpdate {
			updateFlattenedFeeds()
		}
		return _flattenedFeeds
	}

	public func removeFeedFromTreeAtTopLevel(_ feed: Feed) {
		topLevelFeeds.remove(feed)
		structureDidChange()
		postChildrenDidChangeNotification()
	}

	public func removeAllInstancesOfFeedFromTreeAtAllLevels(_ feed: Feed) {
		topLevelFeeds.remove(feed)

		if let folders {
			for folder in folders {
				folder.removeFeedFromTreeAtTopLevel(feed)
			}
		}

		structureDidChange()
		postChildrenDidChangeNotification()
	}

	public func removeFeedsFromTreeAtTopLevel(_ feeds: Set<Feed>) {
		guard !feeds.isEmpty else {
			return
		}
		topLevelFeeds.subtract(feeds)
		structureDidChange()
		postChildrenDidChangeNotification()
	}

	public func addFeedToTreeAtTopLevel(_ feed: Feed) {
		topLevelFeeds.insert(feed)
		structureDidChange()
		postChildrenDidChangeNotification()
	}

	func addFeedIfNotInAnyFolder(_ feed: Feed) {
		if !flattenedFeeds().contains(feed) {
			addFeedToTreeAtTopLevel(feed)
		}
	}

	/// Remove the folder from this account. Does not call delegate.
	func removeFolderFromTree(_ folder: Folder) {
		folders?.remove(folder)
		structureDidChange()
		postChildrenDidChangeNotification()
	}

	// MARK: - Vacuum

	public func vacuumDatabases() async {
		await logActivity(kind: .vacuumDatabase, detail: AppConfig.relativeDataPath(database.databasePath)) {
			await database.vacuum()
		}
		await logActivity(kind: .vacuumDatabase, detail: AppConfig.relativeDataPath(feedSettingsDatabase.databasePath)) {
			await feedSettingsDatabase.vacuum()
		}
		await delegate.vacuumDatabases()
	}

	public func fetchCloudKitStats(progress: @escaping CloudKitStatsProgressHandler) async throws -> CloudKitStats {
		guard type == .cloudKit, let cloudKitDelegate = delegate as? CloudKitAccountDelegate else {
			throw AccountError.invalidParameter
		}
		return try await cloudKitDelegate.fetchCloudKitStats(progress: progress)
	}

	public func cleanUpCloudKit(dryRun: Bool, progress: @escaping @MainActor @Sendable (CloudKitCleanUpProgress) -> Void) async throws {
		guard type == .cloudKit, let cloudKitDelegate = delegate as? CloudKitAccountDelegate else {
			throw AccountError.invalidParameter
		}
		try await cloudKitDelegate.cleanUpCloudKit(dryRun: dryRun, progress: progress)
	}

	public func debugDropConditionalGetInfo() {
#if DEBUG
		for feed in flattenedFeeds() {
			feed.dropConditionalGetInfo()
		}
#endif
	}

	public func debugRunSearch() {
		#if DEBUG
		let t1 = Date()
		let articles = _fetchArticlesMatching(searchString: "Brent NetNewsWire")
		let t2 = Date()
		print(t2.timeIntervalSince(t1))
		print(articles.count)
		#endif
	}

	// MARK: - Notifications

	@objc func progressInfoDidChange(_ note: Notification) {
		progressInfo = delegate.progressInfo
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		if let feed = note.object as? Feed, feed.account === self {
			updateUnreadCount()
		}
	}

    @objc func batchUpdateDidPerform(_ note: Notification) {
		flattenedFeedsNeedUpdate = true
		rebuildFeedDictionaries()
        updateUnreadCount()
    }

	@objc func childrenDidChange(_ note: Notification) {
		guard let object = note.object else {
			return
		}
		if let account = object as? Account, account === self {
			structureDidChange()
			updateUnreadCount()
		}
		if let folder = object as? Folder, folder.account === self {
			structureDidChange()
		}
	}

	@objc func displayNameDidChange(_ note: Notification) {
		if let folder = note.object as? Folder, folder.account === self {
			structureDidChange()
		}
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(accountID)
	}

	// MARK: - Equatable

	public static func ==(lhs: Account, rhs: Account) -> Bool {
		return lhs === rhs
	}
}

// MARK: - Fetching Articles (Private)

private extension Account {

	// MARK: - Credential Errors

	func postCredentialError(_ error: Error, operation: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) {
		let errorLogUserInfo = ErrorLogUserInfoKey.userInfo(sourceName: nameForDisplay, sourceID: type.rawValue, operation: operation, errorMessage: AccountError.detailedErrorMessage(error), fileName: fileName, functionName: functionName, lineNumber: lineNumber)
		NotificationCenter.default.post(name: .appDidEncounterError, object: self, userInfo: errorLogUserInfo)
	}

	// MARK: - Starred Articles

	func _fetchStarredArticles(limit: Int? = nil) -> Set<Article> {
		database.fetchStarredArticles(feedIDs: flattenedFeedsIDs, limit: limit)
	}

	func _fetchStarredArticlesAsync(limit: Int? = nil) async -> Set<Article> {
		await database.fetchedStarredArticlesAsync(feedIDs: flattenedFeedsIDs, limit: limit)
	}

	// MARK: - Account Unread Articles

	func _fetchUnreadArticles(limit: Int? = nil) -> Set<Article> {
		_fetchUnreadArticles(container: self, limit: limit)
	}

	func _fetchUnreadArticlesAsync(limit: Int? = nil) async -> Set<Article> {
		await _fetchUnreadArticlesAsync(container: self, limit: limit)
	}

	// MARK: - Today Articles

	func _fetchTodayArticles(limit: Int? = nil) -> Set<Article> {
		database.fetchTodayArticles(feedIDs: flattenedFeedsIDs, limit: limit)
	}

	func _fetchTodayArticlesAsync(limit: Int? = nil) async -> Set<Article> {
		await database.fetchTodayArticlesAsync(feedIDs: flattenedFeedsIDs, limit: limit)
	}

	// MARK: - Container Articles

	func _fetchArticles(container: Container) -> Set<Article> {
		let feeds = container.flattenedFeeds()
		let articles = database.fetchArticles(feedIDs: feeds.feedIDs())
		validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
		return articles
	}

	func _fetchArticlesAsync(container: Container) async -> Set<Article> {
		let feeds = container.flattenedFeeds()
		let articles = await database.fetchArticlesAsync(feedIDs: feeds.feedIDs())
		validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
		return articles
	}

	func _fetchUnreadArticles(container: Container, limit: Int? = nil) -> Set<Article> {
		let feeds = container.flattenedFeeds()
		let articles = database.fetchUnreadArticles(feedIDs: feeds.feedIDs(), limit: limit)

		// We don't validate limit queries because they, by definition, won't correctly match the
		// complete unread state for the given container.
		if limit == nil {
			validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
		}

		return articles
	}

	func _fetchUnreadArticlesAsync(container: Container, limit: Int? = nil) async -> Set<Article> {
		let feeds = container.flattenedFeeds()
		let articles = await database.fetchUnreadArticlesAsync(feedIDs: feeds.feedIDs(), limit: limit)

		// We don't validate limit queries because they, by definition, won't correctly match the
		// complete unread state for the given container.
		if limit == nil {
			validateUnreadCountsAfterFetchingUnreadArticles(feeds: feeds, articles: articles)
		}

		return articles
	}

	// MARK: - Feed Articles

	func _fetchArticles(feed: Feed) -> Set<Article> {
		let articles = database.fetchArticles(feedID: feed.feedID)
		validateUnreadCount(feed: feed, articles: articles)
		return articles
	}

	func _fetchArticlesAsync(feed: Feed) async -> Set<Article> {
		let articles = await database.fetchArticlesAsync(feedID: feed.feedID)
		validateUnreadCount(feed: feed, articles: articles)
		return articles
	}

	func _fetchUnreadArticles(feed: Feed) -> Set<Article> {
		let articles = database.fetchUnreadArticles(feedIDs: Set([feed.feedID]))
		validateUnreadCount(feed: feed, articles: articles)
		return articles
	}

	// MARK: - ArticleIDs Articles

	func _fetchArticles(articleIDs: Set<String>) -> Set<Article> {
		database.fetchArticles(articleIDs: articleIDs)
	}

	func _fetchArticlesAsync(articleIDs: Set<String>) async -> Set<Article> {
		await database.fetchArticlesAsync(articleIDs: articleIDs)
	}

	// MARK: - Search Articles

	func _fetchArticlesMatching(searchString: String) -> Set<Article> {
		database.fetchArticlesMatching(searchString: searchString, feedIDs: flattenedFeedsIDs)
	}

	func _fetchArticlesMatchingAsync(searchString: String) async -> Set<Article> {
		await database.fetchArticlesMatchingAsync(searchString: searchString, feedIDs: flattenedFeedsIDs)
	}

	func _fetchArticlesMatchingWithArticleIDs(searchString: String, articleIDs: Set<String>) -> Set<Article> {
		database.fetchArticlesMatchingWithArticleIDs(searchString: searchString, articleIDs: articleIDs)
	}

	func _fetchArticlesMatchingWithArticleIDsAsync(searchString: String, articleIDs: Set<String>) async -> Set<Article> {
		await database.fetchArticlesMatchingWithArticleIDsAsync(searchString: searchString, articleIDs: articleIDs)
	}

	// MARK: - Unread Counts

	private func validateUnreadCountsAfterFetchingUnreadArticles(feeds: Set<Feed>, articles: Set<Article>) {
		// Validate unread counts. This was the site of a performance slowdown:
		// it was calling going through the entire list of articles once per feed:
		// feeds.forEach { validateUnreadCount($0, articles) }
		// Now we loop through articles exactly once. This makes a huge difference.

		var unreadCountStorage = [String: Int]() // [FeedID: Int]
		for article in articles where !article.status.read {
			unreadCountStorage[article.feedID, default: 0] += 1
		}
		for feed in feeds {
			let unreadCount = unreadCountStorage[feed.feedID, default: 0]
			feed.unreadCount = unreadCount
		}
	}

	private func validateUnreadCount(feed: Feed, articles: Set<Article>) {
		// articles must contain all the unread articles for the feed.
		// The unread number should match the feed’s unread count.
		var feedUnreadCount = 0
		for article in articles {
			if article.feed == feed && !article.status.read {
				feedUnreadCount += 1
			}
		}
		feed.unreadCount = feedUnreadCount
	}
}

// MARK: - Fetching Unread Counts (Private)

private extension Account {

	/// Fetch unread counts for zero or more feeds.
	///
	/// Uses the most efficient method based on how many feeds were passed in.
	func _fetchUnreadCounts(for feeds: Set<Feed>) {
		if feeds.isEmpty {
			return
		}

		if feeds.count == 1, let feed = feeds.first {
			_fetchUnreadCount(feed: feed)
		} else if feeds.count < 10 {
			_fetchUnreadCounts(feeds: feeds)
		} else {
			_fetchAllUnreadCounts()
		}
	}

	func _fetchUnreadCount(feed: Feed) {
		Task { @MainActor in
			let unreadCount = await database.fetchUnreadCountAsync(feedID: feed.feedID)
			feed.unreadCount = unreadCount
		}
	}

	func _fetchUnreadCounts(feeds: Set<Feed>) {
		Task { @MainActor in
			let unreadCountDictionary = await database.fetchUnreadCountsAsync(feedIDs: feeds.feedIDs())
			processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: feeds)
		}
	}

	func _fetchAllUnreadCounts() {
		fetchingAllUnreadCounts = true

		Task { @MainActor in
			guard let unreadCountDictionary = await database.fetchAllUnreadCountsAsync() else {
				fetchingAllUnreadCounts = false
				return
			}

			processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: flattenedFeeds())
			fetchingAllUnreadCounts = false
			updateUnreadCount()

			if !self.areUnreadCountsInitialized {
				self.areUnreadCountsInitialized = true
				self.postUnreadCountDidInitializeNotification()
			}
		}
	}

	private func processUnreadCounts(unreadCountDictionary: UnreadCountDictionary, feeds: Set<Feed>) {
		for feed in feeds {
			// When the unread count is zero, it won’t appear in unreadCountDictionary.
			let unreadCount = unreadCountDictionary[feed.feedID] ?? 0
			feed.unreadCount = unreadCount
		}
	}
}

// MARK: - Private

private extension Account {

	func populateFeedSettingsCache() {
		let rows = feedSettingsDatabase.allRows()
		for (feedURL, row) in rows {
			feedSettingsCache[feedURL] = FeedSettings(feedURL: feedURL, row: row, database: feedSettingsDatabase)
		}
	}

	func feedSettings(feedURL: String, feedID: String) -> FeedSettings {
		if let d = feedSettingsCache[feedURL] {
			return d
		}
		let d = FeedSettings(feedURL: feedURL, feedID: feedID, database: feedSettingsDatabase)
		feedSettingsCache[feedURL] = d
		return d
	}

	func updateFlattenedFeeds() {
		var feeds = Set<Feed>()
		feeds.formUnion(topLevelFeeds)
		if let folders {
			for folder in folders {
				feeds.formUnion(folder.flattenedFeeds())
			}
		}

		_flattenedFeeds = feeds
		flattenedFeedsNeedUpdate = false
	}

	func rebuildFeedDictionaries() {
		var idDictionary = [String: Feed]()
		var externalIDDictionary = [String: Feed]()

		for feed in flattenedFeeds() {
			idDictionary[feed.feedID] = feed
			if let externalID = feed.externalID {
				externalIDDictionary[externalID] = feed
			}
		}

		_idToFeedDictionary = idDictionary
		_externalIDToFeedDictionary = externalIDDictionary
		feedDictionariesNeedUpdate = false
	}

    func updateUnreadCount() {
		if fetchingAllUnreadCounts {
			return
		}
		var updatedUnreadCount = 0
		for feed in flattenedFeeds() {
			updatedUnreadCount += feed.unreadCount
		}
		unreadCount = updatedUnreadCount
    }

	func noteStatusesForArticleIDsDidChange(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) {
		_fetchAllUnreadCounts()
		NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.articleIDs: articleIDs, UserInfoKey.statusKey: statusKey, UserInfoKey.statusFlag: flag])
	}

	func noteStatusesForArticleIDsDidChange(_ articleIDs: Set<String>) {
		_fetchAllUnreadCounts()
		NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.articleIDs: articleIDs])
	}

	func sendNotificationAbout(_ articleChanges: ArticleChanges) {
		var feeds = Set<Feed>()

		if let newArticles = articleChanges.new {
			feeds.formUnion(Set(newArticles.compactMap { $0.feed }))
		}
		if let updatedArticles = articleChanges.updated {
			feeds.formUnion(Set(updatedArticles.compactMap { $0.feed }))
		}

		var shouldSendNotification = false
		var shouldUpdateUnreadCounts = false
		var userInfo = [String: Any]()

		if let newArticles = articleChanges.new, !newArticles.isEmpty {
			shouldSendNotification = true
			shouldUpdateUnreadCounts = true
			userInfo[UserInfoKey.newArticles] = newArticles
		}

		if let updatedArticles = articleChanges.updated, !updatedArticles.isEmpty {
			shouldSendNotification = true
			userInfo[UserInfoKey.updatedArticles] = updatedArticles
		}

		if let deletedArticles = articleChanges.deleted, !deletedArticles.isEmpty {
			shouldUpdateUnreadCounts = true
		}

		if shouldUpdateUnreadCounts {
			updateUnreadCounts(feeds: feeds)
		}

		if shouldSendNotification {
			userInfo[UserInfoKey.feeds] = feeds
			NotificationCenter.default.postOnMainThread(name: .AccountDidDownloadArticles, object: self, userInfo: userInfo)
		}
	}
}

// MARK: - Container Overrides

extension Account {

	public func existingFeed(withFeedID feedID: String) -> Feed? {
		return idToFeedDictionary[feedID]
	}

	public func existingFeed(withExternalID externalID: String) -> Feed? {
		return externalIDToFeedDictionary[externalID]
	}
}

// MARK: - OPMLRepresentable

extension Account: OPMLRepresentable {

	public func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
		var s = ""
		for feed in topLevelFeeds.sorted() {
			s += feed.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
		}
		for folder in folders!.sorted() {
			s += folder.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
		}
		return s
	}
}
