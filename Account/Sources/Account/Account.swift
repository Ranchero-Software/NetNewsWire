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
import Articles
import RSParser
import Database
import ArticlesDatabase
import RSWeb
import os.log
import Secrets
import Core

// Main thread only.

public extension Notification.Name {
	static let UserDidAddAccount = Notification.Name("UserDidAddAccount")
	static let UserDidDeleteAccount = Notification.Name("UserDidDeleteAccount")
	static let AccountRefreshDidBegin = Notification.Name(rawValue: "AccountRefreshDidBegin")
	static let AccountRefreshDidFinish = Notification.Name(rawValue: "AccountRefreshDidFinish")
	static let AccountRefreshProgressDidChange = Notification.Name(rawValue: "AccountRefreshProgressDidChange")
	static let AccountDidDownloadArticles = Notification.Name(rawValue: "AccountDidDownloadArticles")
	static let AccountStateDidChange = Notification.Name(rawValue: "AccountStateDidChange")
	static let StatusesDidChange = Notification.Name(rawValue: "StatusesDidChange")
}

public enum AccountType: Int, Codable {
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

@MainActor public final class Account: DisplayNameProvider, UnreadCountProvider, Container, Hashable {

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

	public static let defaultLocalAccountName: String = {
		let defaultName: String
		#if os(macOS)
		defaultName = NSLocalizedString("On My Mac", comment: "Account name")
		#else
		if UIDevice.current.userInterfaceIdiom == .pad {
			defaultName = NSLocalizedString("On My iPad", comment: "Account name")
		} else {
			defaultName = NSLocalizedString("On My iPhone", comment: "Account name")
		}
		#endif
		
		return defaultName
	}()
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "account")

	public var isDeleted = false
	
	public var containerID: ContainerIdentifier? {
		return ContainerIdentifier.account(accountID)
	}
	
	public var account: Account? {
		return self
	}
	public let accountID: String
	public let type: AccountType
	public var nameForDisplay: String {
		guard let name = name, !name.isEmpty else {
			return defaultName
		}
		return name
	}

	public var name: String? {
		get {
			return metadata.name
		}
		set {
			let currentNameForDisplay = nameForDisplay
			if newValue != metadata.name {
				metadata.name = newValue
				if currentNameForDisplay != nameForDisplay {
					postDisplayNameDidChangeNotification()
				}
			}
		}
	}
	public let defaultName: String
	
	public var isActive: Bool {
		get {
			return metadata.isActive
		}
		set {
			if newValue != metadata.isActive {
				metadata.isActive = newValue
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
			return metadata.externalID
		}
		set {
			metadata.externalID = newValue
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
		return Set(flattenedFeeds().map({ $0.url }))
	}

	var username: String? {
		get {
			return metadata.username
		}
		set {
			if newValue != metadata.username {
				metadata.username = newValue
			}
		}
	}
	
	public var endpointURL: URL? {
		get {
			return metadata.endpointURL
		}
		set {
			if newValue != metadata.endpointURL {
				metadata.endpointURL = newValue
			}
		}
	}
	
	private var fetchingAllUnreadCounts = false
	var isUnreadCountsInitialized = false

	let dataFolder: String
	let database: ArticlesDatabase
	var delegate: AccountDelegate
	@MainActor static let saveQueue = CoalescingQueue(name: "Account Save Queue", interval: 1.0)

	private var unreadCounts = [String: Int]() // [feedID: Int]

	private var _flattenedFeeds = Set<Feed>()
	private var flattenedFeedsNeedUpdate = true

	@MainActor private lazy var opmlFile = OPMLFile(filename: (dataFolder as NSString).appendingPathComponent("Subscriptions.opml"), account: self)
	@MainActor private lazy var metadataFile = AccountMetadataFile(filename: (dataFolder as NSString).appendingPathComponent("Settings.plist"), account: self)
	var metadata = AccountMetadata() {
		didSet {
			delegate.accountMetadata = metadata
		}
	}

	private lazy var feedMetadataFile = FeedMetadataFile(filename: (dataFolder as NSString).appendingPathComponent("FeedMetadata.plist"), account: self)
	typealias FeedMetadataDictionary = [String: FeedMetadata]
	var feedMetadata = FeedMetadataDictionary()

    public var unreadCount = 0 {
        didSet {
            if unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }
    
	public var behaviors: AccountBehaviors {
		return delegate.behaviors
	}
	
	var refreshInProgress = false {
		didSet {
			if refreshInProgress != oldValue {
				if refreshInProgress {
					NotificationCenter.default.post(name: .AccountRefreshDidBegin, object: self)
				}
				else {
					NotificationCenter.default.post(name: .AccountRefreshDidFinish, object: self)
					Task { @MainActor in
						opmlFile.markAsDirty()
					}
				}
			}
		}
	}

	var refreshProgress: DownloadProgress {
		return delegate.refreshProgress
	}

	@MainActor init(dataFolder: String, type: AccountType, accountID: String, secretsProvider: SecretsProvider, transport: Transport? = nil) {
		switch type {
		case .onMyMac:
			self.delegate = LocalAccountDelegate()
		case .cloudKit:
			self.delegate = CloudKitAccountDelegate(dataFolder: dataFolder)
		case .feedbin:
			self.delegate = FeedbinAccountDelegate(dataFolder: dataFolder, transport: transport)
		case .feedly:
			self.delegate = FeedlyAccountDelegate(dataFolder: dataFolder, transport: transport, api: FeedlyAccountDelegate.environment, secretsProvider: secretsProvider)
		case .newsBlur:
			self.delegate = NewsBlurAccountDelegate(dataFolder: dataFolder, transport: transport)
		case .freshRSS:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, transport: transport, variant: .freshRSS, secretsProvider: secretsProvider)
		case .inoreader:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, transport: transport, variant: .inoreader, secretsProvider: secretsProvider)
		case .bazQux:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, transport: transport, variant: .bazQux, secretsProvider: secretsProvider)
		case .theOldReader:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, transport: transport, variant: .theOldReader, secretsProvider: secretsProvider)
		}

		self.delegate.accountMetadata = metadata
		
		self.accountID = accountID
		self.type = type
		self.dataFolder = dataFolder

		let databasePath = (dataFolder as NSString).appendingPathComponent("DB.sqlite3")
		let retentionStyle: ArticlesDatabase.RetentionStyle = (type == .onMyMac || type == .cloudKit) ? .feedBased : .syncSystem
		self.database = ArticlesDatabase(databasePath: databasePath, accountID: accountID, retentionStyle: retentionStyle)

		switch type {
		case .onMyMac:
			defaultName = Account.defaultLocalAccountName
		case .cloudKit:
			defaultName = NSLocalizedString("iCloud", comment: "iCloud")
		case .feedly:
			defaultName = NSLocalizedString("Feedly", comment: "Feedly")
		case .feedbin:
			defaultName = NSLocalizedString("Feedbin", comment: "Feedbin")
		case .newsBlur:
			defaultName = NSLocalizedString("NewsBlur", comment: "NewsBlur")
		case .freshRSS:
			defaultName = NSLocalizedString("FreshRSS", comment: "FreshRSS")
		case .inoreader:
			defaultName = NSLocalizedString("Inoreader", comment: "Inoreader")
		case .bazQux:
			defaultName = NSLocalizedString("BazQux", comment: "BazQux")
		case .theOldReader:
			defaultName = NSLocalizedString("The Old Reader", comment: "The Old Reader")
		}

		NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressDidChange(_:)), name: .DownloadProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(childrenDidChange(_:)), name: .ChildrenDidChange, object: nil)

		metadataFile.load()
		feedMetadataFile.load()
		opmlFile.load()

		Task { @MainActor in
			try? await self.database.cleanupDatabaseAtStartup(subscribedToFeedIDs: self.flattenedFeeds().feedIDs())
			self.fetchAllUnreadCounts()
		}

		self.delegate.accountDidInitialize(self)
	}
	
	// MARK: - API
	
	public func storeCredentials(_ credentials: Credentials) throws {
		username = credentials.username
		guard let server = delegate.server else {
			assertionFailure()
			return
		}
		try CredentialsManager.storeCredentials(credentials, server: server)
		delegate.credentials = credentials
	}
	
	public func retrieveCredentials(type: CredentialsType) throws -> Credentials? {
		guard let username = self.username, let server = delegate.server else {
			return nil
		}
		return try CredentialsManager.retrieveCredentials(type: type, server: server, username: username)
	}
	
	public func removeCredentials(type: CredentialsType) throws {
		guard let username = self.username, let server = delegate.server else {
			return
		}
		try CredentialsManager.removeCredentials(type: type, server: server, username: username)
	}
	
	public static func validateCredentials(transport: Transport = URLSession.webserviceTransport(), type: AccountType, credentials: Credentials, endpoint: URL? = nil, secretsProvider: SecretsProvider, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		switch type {
		case .feedbin:
			FeedbinAccountDelegate.validateCredentials(transport: transport, credentials: credentials, secretsProvider: secretsProvider, completion: completion)
		case .newsBlur:
			NewsBlurAccountDelegate.validateCredentials(transport: transport, credentials: credentials, secretsProvider: secretsProvider, completion: completion)
		case .freshRSS, .inoreader, .bazQux, .theOldReader:
			ReaderAPIAccountDelegate.validateCredentials(transport: transport, credentials: credentials, endpoint: endpoint, secretsProvider: secretsProvider, completion: completion)
		default:
			break
		}
	}
	
	internal static func oauthAuthorizationClient(for type: AccountType, secretsProvider: SecretsProvider) -> OAuthAuthorizationClient {
		switch type {
		case .feedly:
			return FeedlyAccountDelegate.environment.oauthAuthorizationClient(secretsProvider: secretsProvider)
		default:
			fatalError("\(type) is not a client for OAuth authorization code granting.")
		}
	}
		
	public static func oauthAuthorizationCodeGrantRequest(for type: AccountType, secretsProvider: SecretsProvider) -> URLRequest {
		let grantingType: OAuthAuthorizationGranting.Type
		switch type {
		case .feedly:
			grantingType = FeedlyAccountDelegate.self
		default:
			fatalError("\(type) does not support OAuth authorization code granting.")
		}
		
		return grantingType.oauthAuthorizationCodeGrantRequest(secretsProvider: secretsProvider)
	}
	
	public static func requestOAuthAccessToken(with response: OAuthAuthorizationResponse,
											   client: OAuthAuthorizationClient,
											   accountType: AccountType,
											   transport: Transport = URLSession.webserviceTransport(),
											   secretsProvider: SecretsProvider,
											   completion: @escaping (Result<OAuthAuthorizationGrant, Error>) -> ()) {
		let grantingType: OAuthAuthorizationGranting.Type
		
		switch accountType {
		case .feedly:
			grantingType = FeedlyAccountDelegate.self
		default:
			fatalError("\(accountType) does not support OAuth authorization code granting.")
		}
		
		grantingType.requestOAuthAccessToken(with: response, transport: transport, secretsProvider: secretsProvider, completion: completion)
	}

	private func receiveRemoteNotification(userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		delegate.receiveRemoteNotification(for: self, userInfo: userInfo, completion: completion)
	}
	
	public func receiveRemoteNotification(userInfo: [AnyHashable: Any]) async {
		await withCheckedContinuation { continuation in
			self.receiveRemoteNotification(userInfo: userInfo) {
				continuation.resume()
			}
		}
	}

	public func refreshAll(completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.refreshAll(for: self, completion: completion)
	}

	public func sendArticleStatus(completion: ((Result<Void, Error>) -> Void)? = nil) {
		delegate.sendArticleStatus(for: self) { result in
			switch result {
			case .success:
				completion?(.success(()))
			case .failure(let error):
				completion?(.failure(error))
			}
		}
	}
	
	public func syncArticleStatus(completion: ((Result<Void, Error>) -> Void)? = nil) {
		delegate.syncArticleStatus(for: self, completion: completion)
	}
	
	public func importOPML(_ opmlFile: URL, completion: @escaping (Result<Void, Error>) -> Void) {
		guard !delegate.isOPMLImportInProgress else {
			completion(.failure(AccountError.opmlImportInProgress))
			return
		}
		
		delegate.importOPML(for: self, opmlFile: opmlFile) { [weak self] result in
			switch result {
			case .success:
				guard let self = self else { return }
				// Reset the last fetch date to get the article history for the added feeds.
				self.metadata.lastArticleFetchStartTime = nil
				self.delegate.refreshAll(for: self, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	public func suspendNetwork() {
		delegate.suspendNetwork()
	}
	
	public func suspendDatabase() {
		#if os(iOS)
		Task {
			await database.suspend()
		}
		#endif
		save()
	}

	/// Re-open the SQLite database and allow database calls.
	/// Call this *before* calling resume.
	public func resumeDatabaseAndDelegate() {
		#if os(iOS)
		Task {
			await database.resume()
		}
		#endif
		delegate.resume()
	}

	/// Reload OPML, etc.
	public func resume() {
		fetchAllUnreadCounts()
	}

	public func save() {
		Task { @MainActor in
			metadataFile.save()
			feedMetadataFile.save()
			opmlFile.save()
		}
	}
	
	public func prepareForDeletion() {
		delegate.accountWillBeDeleted(self)
	}

	func addOPMLItems(_ items: [RSOPMLItem]) {
		for item in items {
			if let feedSpecifier = item.feedSpecifier {
				addFeed(newFeed(with: feedSpecifier))
			} else {
				if let title = item.titleFromAttributes, let folder = ensureFolder(with: title) {
					folder.externalID = item.attributes?["nnw_externalID"] as? String
					item.children?.forEach { itemChild in
						if let feedSpecifier = itemChild.feedSpecifier {
							folder.addFeed(newFeed(with: feedSpecifier))
						}
					}
				}
			}
		}
	}
	
	func loadOPMLItems(_ items: [RSOPMLItem]) {
		addOPMLItems(OPMLNormalizer.normalize(items))		
	}
	
	public func markArticles(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.markArticles(for: self, articles: articles, statusKey: statusKey, flag: flag, completion: completion)
	}

	func existingContainer(withExternalID externalID: String) -> Container? {
		guard self.externalID != externalID else {
			return self
		}
		return existingFolder(withExternalID: externalID)
	}
	
	func existingContainers(withFeed feed: Feed) -> [Container] {
		var containers = [Container]()
		if topLevelFeeds.contains(feed) {
			containers.append(self)
		}
		folders?.forEach { folder in
			if folder.topLevelFeeds.contains(feed) {
				containers.append(folder)
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
	
	func newFeed(with opmlFeedSpecifier: RSOPMLFeedSpecifier) -> Feed {
		let feedURL = opmlFeedSpecifier.feedURL
		let metadata = feedMetadata(feedURL: feedURL, feedID: feedURL)
		let feed = Feed(account: self, url: opmlFeedSpecifier.feedURL, metadata: metadata)
		if let feedTitle = opmlFeedSpecifier.title {
			if feed.name == nil {
				feed.name = feedTitle
			}
		}
		return feed
	}

	public func addFeed(_ feed: Feed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.addFeed(for: self, with: feed, to: container, completion: completion)
	}

	public func createFeed(url: String, name: String?, container: Container, validateFeed: Bool, completion: @escaping (Result<Feed, Error>) -> Void) {
		delegate.createFeed(for: self, url: url, name: name, container: container, validateFeed: validateFeed, completion: completion)
	}
	
	func createFeed(with name: String?, url: String, feedID: String, homePageURL: String?) -> Feed {
		let metadata = feedMetadata(feedURL: url, feedID: feedID)
		let feed = Feed(account: self, url: url, metadata: metadata)
		feed.name = name
		feed.homePageURL = homePageURL
		return feed
	}
	
	public func removeFeed(_ feed: Feed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.removeFeed(for: self, with: feed, from: container, completion: completion)
	}
	
	public func moveFeed(_ feed: Feed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.moveFeed(for: self, with: feed, from: from, to: to, completion: completion)
	}
	
	public func renameFeed(_ feed: Feed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.renameFeed(for: self, with: feed, to: name, completion: completion)
	}
	
	public func restoreFeed(_ feed: Feed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.restoreFeed(for: self, feed: feed, container: container, completion: completion)
	}
	
	public func addFolder(_ name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		delegate.createFolder(for: self, name: name, completion: completion)
	}
	
	public func removeFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.removeFolder(for: self, with: folder, completion: completion)
	}
	
	public func renameFolder(_ folder: Folder, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.renameFolder(for: self, with: folder, to: name, completion: completion)
	}

	public func restoreFolder(_ folder: Folder, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.restoreFolder(for: self, folder: folder, completion: completion)
	}
	
	func clearFeedMetadata(_ feed: Feed) {
		feedMetadata[feed.url] = nil
	}
	
	func addFolder(_ folder: Folder) {
		folders!.insert(folder)
		postChildrenDidChangeNotification()
		structureDidChange()
	}
	
	public func updateUnreadCounts(for feeds: Set<Feed>, completion: VoidCompletionBlock? = nil) {
		fetchUnreadCounts(for: feeds, completion: completion)
	}

	@MainActor public func articles(for fetchType: FetchType) async throws -> Set<Article> {

		switch fetchType {

		case .starred(let limit):
			return try await starredArticles(limit: limit)

		case .unread(let limit):
			return try await unreadArticles(limit: limit)

		case .today(let limit):
			return try await todayArticles(limit: limit)

		case .folder(let folder, let readFilter):
			if readFilter {
				return try await unreadArticles(folder: folder)
			} else {
				return try await articles(folder: folder)
			}

		case .feed(let feed):
			return try await articles(feed: feed)

		case .articleIDs(let articleIDs):
			return try await articles(articleIDs: articleIDs)

		case .search(let searchString):
			return try await articlesMatching(searchString: searchString)

		case .searchWithArticleIDs(let searchString, let articleIDs):
			return try await articlesMatching(searchString: searchString, articleIDs: articleIDs)
		}

	}

	public func fetchArticlesAsync(_ fetchType: FetchType, _ completion: @escaping ArticleSetResultBlock) {
		switch fetchType {
		case .starred(let limit):
			fetchStarredArticlesAsync(limit: limit, completion)
		case .unread(let limit):
			fetchUnreadArticlesAsync(limit: limit, completion)
		case .today(let limit):
			fetchTodayArticlesAsync(limit: limit, completion)
		case .folder(let folder, let readFilter):
			if readFilter {
				return fetchUnreadArticlesAsync(folder: folder, completion)
			} else {
				return fetchArticlesAsync(folder: folder, completion)
			}
		case .feed(let feed):
			fetchArticlesAsync(feed: feed, completion)
		case .articleIDs(let articleIDs):
			fetchArticlesAsync(articleIDs: articleIDs, completion)
		case .search(let searchString):
			fetchArticlesMatchingAsync(searchString, completion)
		case .searchWithArticleIDs(let searchString, let articleIDs):
			return fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, completion)
		}
	}

	@MainActor public func articles(feed: Feed) async throws -> Set<Article> {

		let articles = try await database.articles(feedID: feed.feedID)
		validateUnreadCount(feed, articles)
		return articles
	}
	
	public func articles(articleIDs: Set<String>) async throws -> Set<Article> {

		try await database.articles(articleIDs: articleIDs)
	}

	@MainActor public func unreadArticles(feed: Feed) async throws -> Set<Article> {

		try await database.unreadArticles(feedIDs: Set([feed.feedID]))
	}

	@MainActor public func unreadArticles(feeds: Set<Feed>) async throws -> Set<Article> {

		if feeds.isEmpty {
			return Set<Article>()
		}

		let feedIDs = feeds.feedIDs()
		let articles = try await database.unreadArticles(feedIDs: feedIDs)
		
		validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)

		return articles
	}

	public func unreadArticles(folder: Folder) async throws -> Set<Article> {

		let feeds = folder.flattenedFeeds()
		return try await unreadArticles(feeds: feeds)
	}

	public func unreadCountForToday() async throws -> Int {
		
		try await database.unreadCountForToday(feedIDs: allFeedIDs()) ?? 0
	}

	public func fetchUnreadCountForToday(_ completion: @escaping SingleUnreadCountCompletionBlock) {
		
		database.fetchUnreadCountForToday(for: flattenedFeeds().feedIDs(), completion: completion)
	}

	public func unreadCountForStarredArticles() async throws -> Int {

		try await database.starredAndUnreadCount(feedIDs: allFeedIDs()) ?? 0
	}

	public func fetchUnreadCountForStarredArticles(_ completion: @escaping SingleUnreadCountCompletionBlock) {
		database.fetchStarredAndUnreadCount(for: flattenedFeeds().feedIDs(), completion: completion)
	}

	public func fetchUnreadArticleIDs(_ completion: @escaping ArticleIDsCompletionBlock) {
		database.fetchUnreadArticleIDsAsync(completion: completion)
	}

	public func fetchStarredArticleIDs(_ completion: @escaping ArticleIDsCompletionBlock) {
		database.fetchStarredArticleIDsAsync(completion: completion)
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are either (starred) or (newer than the article cutoff date).
	public func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(_ completion: @escaping ArticleIDsCompletionBlock) {
		database.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(completion)
	}
	
	public func unreadCount(for feed: Feed) -> Int {
		return unreadCounts[feed.feedID] ?? 0
	}

	public func setUnreadCount(_ unreadCount: Int, for feed: Feed) {
		unreadCounts[feed.feedID] = unreadCount
	}

	public func structureDidChange() {
		// Feeds were added or deleted. Or folders added or deleted.
		// Or feeds inside folders were added or deleted.
		Task { @MainActor in
			opmlFile.markAsDirty()
			flattenedFeedsNeedUpdate = true
			feedDictionariesNeedUpdate = true
		}
	}

	func update(_ feed: Feed, with parsedFeed: ParsedFeed, _ completion: @escaping UpdateArticlesCompletionBlock) {
		// Used only by an On My Mac or iCloud account.
		precondition(Thread.isMainThread)
		precondition(type == .onMyMac || type == .cloudKit)

		feed.takeSettings(from: parsedFeed)
		let parsedItems = parsedFeed.items
		guard !parsedItems.isEmpty else {
			completion(.success(ArticleChanges()))
			return
		}
		
		update(feed.feedID, with: parsedItems, completion: completion)
	}
	
	func update(_ feedID: String, with parsedItems: Set<ParsedItem>, deleteOlder: Bool = true, completion: @escaping UpdateArticlesCompletionBlock) {
		// Used only by an On My Mac or iCloud account.
		precondition(Thread.isMainThread)
		precondition(type == .onMyMac || type == .cloudKit)
		
		database.update(with: parsedItems, feedID: feedID, deleteOlder: deleteOlder) { updateArticlesResult in

			MainActor.assumeIsolated {
				switch updateArticlesResult {
				case .success(let articleChanges):
					self.sendNotificationAbout(articleChanges)
					completion(.success(articleChanges))
				case .failure(let databaseError):
					completion(.failure(databaseError))
				}
			}
		}
	}

	func update(feedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping DatabaseCompletionBlock) {
		// Used only by syncing systems.
		precondition(Thread.isMainThread)
		precondition(type != .onMyMac && type != .cloudKit)
		guard !feedIDsAndItems.isEmpty else {
			completion(nil)
			return
		}

		database.update(feedIDsAndItems: feedIDsAndItems, defaultRead: defaultRead) { updateArticlesResult in

			MainActor.assumeIsolated {
				switch updateArticlesResult {
				case .success(let newAndUpdatedArticles):
					self.sendNotificationAbout(newAndUpdatedArticles)
					completion(nil)
				case .failure(let databaseError):
					completion(databaseError)
				}
			}
		}
	}

	func update(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, completion: @escaping ArticleSetResultBlock) {
		// Returns set of Articles whose statuses did change.
		guard !articles.isEmpty else {
			completion(.success(Set<Article>()))
			return
		}
		
		database.mark(articles, statusKey: statusKey, flag: flag) { result in

			MainActor.assumeIsolated {
				switch result {
				case .success(let updatedStatuses):
					let updatedArticleIDs = updatedStatuses.articleIDs()
					let updatedArticles = Set(articles.filter{ updatedArticleIDs.contains($0.articleID) })
					self.noteStatusesForArticlesDidChange(updatedArticles)
					completion(.success(updatedArticles))
				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	}

	/// Make sure statuses exist. Any existing statuses won’t be touched.
	/// All created statuses will be marked as read and not starred.
	/// Sends a .StatusesDidChange notification.
	func createStatusesIfNeeded(articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		guard !articleIDs.isEmpty else {
			completion?(nil)
			return
		}
		database.createStatusesIfNeeded(articleIDs: articleIDs) { error in

			MainActor.assumeIsolated {
				if let error = error {
					completion?(error)
					return
				}
				self.noteStatusesForArticleIDsDidChange(articleIDs)
				completion?(nil)
			}
		}
	}

	/// Mark articleIDs statuses based on statusKey and flag.
	/// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	/// Returns a set of new article statuses.
	func mark(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, completion: DatabaseCompletionBlock? = nil) {
		guard !articleIDs.isEmpty else {
			completion?(nil)
			return
		}
		database.mark(articleIDs: articleIDs, statusKey: statusKey, flag: flag) { error in
			MainActor.assumeIsolated {
				if let error {
					completion?(error)
				} else {
					self.noteStatusesForArticleIDsDidChange(articleIDs: articleIDs, statusKey: statusKey, flag: flag)
					completion?(nil)
				}
			}
		}
	}

	/// Mark articleIDs as read. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	/// Returns a set of new article statuses.
	func markAsRead(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .read, flag: true, completion: completion)
	}

	/// Mark articleIDs as unread. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	/// Returns a set of new article statuses.
	func markAsUnread(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .read, flag: false, completion: completion)
	}

	/// Mark articleIDs as starred. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	/// Returns a set of new article statuses.
	func markAsStarred(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .starred, flag: true, completion: completion)
	}

	/// Mark articleIDs as unstarred. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	/// Returns a set of new article statuses.
	func markAsUnstarred(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .starred, flag: false, completion: completion)
	}

	// Delete the articles associated with the given set of articleIDs
	func delete(articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		guard !articleIDs.isEmpty else {
			completion?(nil)
			return
		}
		database.delete(articleIDs: articleIDs, completion: completion)
	}
	
	/// Empty caches that can reasonably be emptied. Call when the app goes in the background, for instance.
	func emptyCaches() {

		Task.detached {
			await self.database.emptyCaches()
		}
	}

	// MARK: - Container

	public func flattenedFeeds() -> Set<Feed> {
		assert(Thread.isMainThread)
		if flattenedFeedsNeedUpdate {
			updateFlattenedFeeds()
		}
		return _flattenedFeeds
	}

	public func removeFeed(_ feed: Feed) {
		topLevelFeeds.remove(feed)
		structureDidChange()
		postChildrenDidChangeNotification()
	}
	
	public func removeFeeds(_ feeds: Set<Feed>) {
		guard !feeds.isEmpty else {
			return
		}
		topLevelFeeds.subtract(feeds)
		structureDidChange()
		postChildrenDidChangeNotification()
	}
	
	public func addFeed(_ feed: Feed) {
		topLevelFeeds.insert(feed)
		structureDidChange()
		postChildrenDidChangeNotification()
	}

	func addFeedIfNotInAnyFolder(_ feed: Feed) {
		if !flattenedFeeds().contains(feed) {
			addFeed(feed)
		}
	}
	
	func removeFolder(_ folder: Folder) {
		folders?.remove(folder)
		structureDidChange()
		postChildrenDidChangeNotification()
	}
	
	// MARK: - Debug

	public func debugDropConditionalGetInfo() {
		#if DEBUG
			flattenedFeeds().forEach{ $0.dropConditionalGetInfo() }
		#endif
	}

	public func debugRunSearch() {
		#if DEBUG
		Task {
			let t1 = Date()
			let articles = try! await articlesMatching(searchString: "Brent NetNewsWire")
			let t2 = Date()
			print(t2.timeIntervalSince(t1))
			print(articles.count)
		}
		#endif
	}

	// MARK: - Notifications

	@objc func downloadProgressDidChange(_ note: Notification) {
		guard let noteObject = note.object as? DownloadProgress, noteObject === refreshProgress else {
			return
		}

		refreshInProgress = refreshProgress.numberRemaining > 0
		NotificationCenter.default.post(name: .AccountRefreshProgressDidChange, object: self)
	}
	
	@MainActor @objc func unreadCountDidChange(_ note: Notification) {
		if let feed = note.object as? Feed, feed.account === self {
			updateUnreadCount()
		}
	}
    
	@MainActor @objc func batchUpdateDidPerform(_ note: Notification) {
		flattenedFeedsNeedUpdate = true
		rebuildFeedDictionaries()
        updateUnreadCount()
    }

	@MainActor @objc func childrenDidChange(_ note: Notification) {
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

	public class func ==(lhs: Account, rhs: Account) -> Bool {
		return lhs === rhs
	}
}

// MARK: - AccountMetadataDelegate

extension Account: AccountMetadataDelegate {
	func valueDidChange(_ accountMetadata: AccountMetadata, key: AccountMetadata.CodingKeys) {
		Task { @MainActor in
			metadataFile.markAsDirty()
		}
	}
}

// MARK: - FeedMetadataDelegate

extension Account: FeedMetadataDelegate {

	func valueDidChange(_ feedMetadata: FeedMetadata, key: FeedMetadata.CodingKeys) {

		Task { @MainActor in
			feedMetadataFile.markAsDirty()
			guard let feed = existingFeed(withFeedID: feedMetadata.feedID) else {
				return
			}
			feed.postFeedSettingDidChangeNotification(key)
		}
	}
}

// MARK: - Fetching (Private)

private extension Account {

	func starredArticles(limit: Int? = nil) async throws -> Set<Article> {

		try await database.starredArticles(feedIDs: allFeedIDs(), limit: limit)
	}

	func fetchStarredArticlesAsync(limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		database.fetchedStarredArticlesAsync(allFeedIDs(), limit, completion)
	}

	func unreadArticles(limit: Int? = nil) async throws -> Set<Article> {

		try await unreadArticles(container: self)
	}

	func fetchUnreadArticlesAsync(limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		fetchUnreadArticlesAsync(forContainer: self, limit: limit, completion)
	}

	func todayArticles(limit: Int? = nil) async throws -> Set<Article> {
		
		try await database.todayArticles(feedIDs: allFeedIDs(), limit: limit)
	}

	func fetchTodayArticlesAsync(limit: Int?, _ completion: @escaping ArticleSetResultBlock) {

		database.fetchTodayArticlesAsync(allFeedIDs(), limit, completion)
	}

	func articles(folder: Folder) async throws -> Set<Article> {

		try await articles(container: folder)
	}

	func fetchArticlesAsync(folder: Folder, _ completion: @escaping ArticleSetResultBlock) {

		fetchArticlesAsync(forContainer: folder, completion)
	}

	func fetchUnreadArticlesAsync(folder: Folder, _ completion: @escaping ArticleSetResultBlock) {

		fetchUnreadArticlesAsync(forContainer: folder, limit: nil, completion)
	}

	func fetchArticlesAsync(feed: Feed, _ completion: @escaping ArticleSetResultBlock) {
		database.fetchArticlesAsync(feed.feedID) { [weak self] articleSetResult in

			MainActor.assumeIsolated {
				switch articleSetResult {
				case .success(let articles):
					self?.validateUnreadCount(feed, articles)
					completion(.success(articles))
				case .failure(let databaseError):
					completion(.failure(databaseError))
				}
			}
		}
	}

	func articlesMatching(searchString: String) async throws -> Set<Article> {

		try await database.articlesMatching(searchString: searchString, feedIDs: allFeedIDs())
	}

	func fetchArticlesMatchingAsync(_ searchString: String, _ completion: @escaping ArticleSetResultBlock) {
		
		database.fetchArticlesMatchingAsync(searchString, flattenedFeeds().feedIDs(), completion)
	}

	func articlesMatching(searchString: String, articleIDs: Set<String>) async throws -> Set<Article> {

		try await database.articlesMatching(searchString: searchString, articleIDs: articleIDs)
	}

	func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		
		database.fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, completion)
	}

	func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		
		return database.fetchArticlesAsync(articleIDs: articleIDs, completion)
	}

	@MainActor func articles(container: Container) async throws -> Set<Article> {

		let feeds = container.flattenedFeeds()
		let articles = try await database.articles(feedIDs: allFeedIDs())

		validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)

		return articles
	}

	func fetchArticlesAsync(forContainer container: Container, _ completion: @escaping ArticleSetResultBlock) {
		let feeds = container.flattenedFeeds()
		database.fetchArticlesAsync(feeds.feedIDs()) { [weak self] (articleSetResult) in

			Task { @MainActor [weak self] in
				switch articleSetResult {
				case .success(let articles):
					self?.validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)
					completion(.success(articles))
				case .failure(let databaseError):
					completion(.failure(databaseError))
				}
			}
		}
	}

	@MainActor func unreadArticles(container: Container, limit: Int? = nil) async throws -> Set<Article> {

		let feeds = container.flattenedFeeds()
		let feedIDs = feeds.feedIDs()
		let articles = try await database.unreadArticles(feedIDs: feedIDs, limit: limit)

		// We don't validate limit queries because they, by definition, won't correctly match the
		// complete unread state for the given container.
		if limit == nil {
			validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)
		}
		
		return articles
	}

	func fetchUnreadArticlesAsync(forContainer container: Container, limit: Int?, _ completion: @escaping ArticleSetResultBlock) {
		let feeds = container.flattenedFeeds()
		database.fetchUnreadArticlesAsync(feeds.feedIDs(), limit) { [weak self] (articleSetResult) in

			Task { @MainActor [weak self] in
				switch articleSetResult {
				case .success(let articles):

					// We don't validate limit queries because they, by definition, won't correctly match the
					// complete unread state for the given container.
					if limit == nil {
						self?.validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)
					}

					completion(.success(articles))
				case .failure(let databaseError):
					completion(.failure(databaseError))
				}
			}
		}
	}

	@MainActor func validateUnreadCountsAfterFetchingUnreadArticles(_ feeds: Set<Feed>, _ articles: Set<Article>) {
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

	@MainActor func validateUnreadCount(_ feed: Feed, _ articles: Set<Article>) {
		// articles must contain all the unread articles for the feed.
		// The unread number should match the feed’s unread count.

		let feedUnreadCount = articles.reduce(0) { (result, article) -> Int in
			if article.feed == feed && !article.status.read {
				return result + 1
			}
			return result
		}

		feed.unreadCount = feedUnreadCount
	}
}

// MARK: - Private

private extension Account {

	func feedMetadata(feedURL: String, feedID: String) -> FeedMetadata {
		if let d = feedMetadata[feedURL] {
			assert(d.delegate === self)
			return d
		}
		let d = FeedMetadata(feedID: feedID)
		d.delegate = self
		feedMetadata[feedURL] = d
		return d
	}

	func updateFlattenedFeeds() {
		var feeds = Set<Feed>()
		feeds.formUnion(topLevelFeeds)
		for folder in folders! {
			feeds.formUnion(folder.flattenedFeeds())
		}

		_flattenedFeeds = feeds
		flattenedFeedsNeedUpdate = false
	}

	/// feedIDs for all feeds in the account, not just top level.
	func allFeedIDs() -> Set<String> {

		flattenedFeeds().feedIDs()
	}

	func rebuildFeedDictionaries() {
		var idDictionary = [String: Feed]()
		var externalIDDictionary = [String: Feed]()
		
		flattenedFeeds().forEach { (feed) in
			idDictionary[feed.feedID] = feed
			if let externalID = feed.externalID {
				externalIDDictionary[externalID] = feed
			}
		}

		_idToFeedDictionary = idDictionary
		_externalIDToFeedDictionary = externalIDDictionary
		feedDictionariesNeedUpdate = false
	}
    
	@MainActor func updateUnreadCount() {
		if fetchingAllUnreadCounts {
			return
		}
		var updatedUnreadCount = 0
		for feed in flattenedFeeds() {
			updatedUnreadCount += feed.unreadCount
		}
		unreadCount = updatedUnreadCount
    }
    
	@MainActor func noteStatusesForArticlesDidChange(_ articles: Set<Article>) {
		let feeds = Set(articles.compactMap { $0.feed })
		let statuses = Set(articles.map { $0.status })
		let articleIDs = Set(articles.map { $0.articleID })

        // .UnreadCountDidChange notification will get sent to Folder and Account objects,
        // which will update their own unread counts.
        updateUnreadCounts(for: feeds)
        
		NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.statuses: statuses, UserInfoKey.articles: articles, UserInfoKey.articleIDs: articleIDs, UserInfoKey.feeds: feeds])
    }

	func noteStatusesForArticleIDsDidChange(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool) {
		fetchAllUnreadCounts()
		NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.articleIDs: articleIDs, UserInfoKey.statusKey: statusKey, UserInfoKey.statusFlag: flag])
	}

	func noteStatusesForArticleIDsDidChange(_ articleIDs: Set<String>) {
		fetchAllUnreadCounts()
		NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.articleIDs: articleIDs])
	}

	/// Fetch unread counts for zero or more feeds.
	///
	/// Uses the most efficient method based on how many feeds were passed in.
	func fetchUnreadCounts(for feeds: Set<Feed>, completion: VoidCompletionBlock?) {
		if feeds.isEmpty {
			completion?()
			return
		}
		if feeds.count == 1, let feed = feeds.first {
			fetchUnreadCount(feed, completion)
		}
		else if feeds.count < 10 {
			fetchUnreadCounts(feeds, completion)
		}
		else {
			fetchAllUnreadCounts(completion)
		}
	}

	func fetchUnreadCount(_ feed: Feed, _ completion: VoidCompletionBlock?) {
		database.fetchUnreadCount(feed.feedID) { result in
			Task { @MainActor in
				if let unreadCount = try? result.get() {
					feed.unreadCount = unreadCount
				}
				completion?()
			}
		}
	}

	func fetchUnreadCounts(_ feeds: Set<Feed>, _ completion: VoidCompletionBlock?) {
		let feedIDs = Set(feeds.map { $0.feedID })
		database.fetchUnreadCounts(for: feedIDs) { result in

			Task { @MainActor in
				if let unreadCountDictionary = try? result.get() {
					self.processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: feeds)
				}
				completion?()
			}
		}
	}

	func fetchAllUnreadCounts(_ completion: VoidCompletionBlock? = nil) {
		fetchingAllUnreadCounts = true
		database.fetchAllUnreadCounts { result in

			Task { @MainActor in
				guard let unreadCountDictionary = try? result.get() else {
					completion?()
					return
				}
				self.processUnreadCounts(unreadCountDictionary: unreadCountDictionary, feeds: self.flattenedFeeds())

				self.fetchingAllUnreadCounts = false
				self.updateUnreadCount()

				if !self.isUnreadCountsInitialized {
					self.isUnreadCountsInitialized = true
					self.postUnreadCountDidInitializeNotification()
				}
				completion?()
			}
		}
	}

	@MainActor func processUnreadCounts(unreadCountDictionary: UnreadCountDictionary, feeds: Set<Feed>) {
		for feed in feeds {
			// When the unread count is zero, it won’t appear in unreadCountDictionary.
			let unreadCount = unreadCountDictionary[feed.feedID] ?? 0
			feed.unreadCount = unreadCount
		}
	}

	@MainActor func sendNotificationAbout(_ articleChanges: ArticleChanges) {
		var feeds = Set<Feed>()

		if let newArticles = articleChanges.newArticles {
			feeds.formUnion(Set(newArticles.compactMap { $0.feed }))
		}
		if let updatedArticles = articleChanges.updatedArticles {
			feeds.formUnion(Set(updatedArticles.compactMap { $0.feed }))
		}

		var shouldSendNotification = false
		var shouldUpdateUnreadCounts = false
		var userInfo = [String: Any]()

		if let newArticles = articleChanges.newArticles, !newArticles.isEmpty {
			shouldSendNotification = true
			shouldUpdateUnreadCounts = true
			userInfo[UserInfoKey.newArticles] = newArticles
		}

		if let updatedArticles = articleChanges.updatedArticles, !updatedArticles.isEmpty {
			shouldSendNotification = true
			userInfo[UserInfoKey.updatedArticles] = updatedArticles
		}

		if let deletedArticles = articleChanges.deletedArticles, !deletedArticles.isEmpty {
			shouldUpdateUnreadCounts = true
		}

		if shouldUpdateUnreadCounts {
			self.updateUnreadCounts(for: feeds)
		}

		if shouldSendNotification {
			userInfo[UserInfoKey.feeds] = feeds
			NotificationCenter.default.post(name: .AccountDidDownloadArticles, object: self, userInfo: userInfo)
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
