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
import os.log

// Main thread only.

public extension Notification.Name {
	static let UserDidAddAccount = Notification.Name("UserDidAddAccount")
	static let UserDidDeleteAccount = Notification.Name("UserDidDeleteAccount")
	static let AccountRefreshDidBegin = Notification.Name(rawValue: "AccountRefreshDidBegin")
	static let AccountRefreshDidFinish = Notification.Name(rawValue: "AccountRefreshDidFinish")
	static let AccountRefreshProgressDidChange = Notification.Name(rawValue: "AccountRefreshProgressDidChange")
	static let DownloadArticlesDidUpdateUnreadCounts = Notification.Name(rawValue: "DownloadArticlesDidUpdateUnreadCounts")
	static let AccountDidDownloadArticles = Notification.Name(rawValue: "AccountDidDownloadArticles")
	static let AccountStateDidChange = Notification.Name(rawValue: "AccountStateDidChange")
	static let StatusesDidChange = Notification.Name(rawValue: "StatusesDidChange")
	static let WebFeedMetadataDidChange = Notification.Name(rawValue: "WebFeedMetadataDidChange")
}

public enum AccountType: Int {
	// Raw values should not change since they’re stored on disk.
	case onMyMac = 1
	case feedly = 16
	case feedbin = 17
	case feedWrangler = 18
	case newsBlur = 19
	case freshRSS = 20
	// TODO: more
}

public enum FetchType {
	case starred
	case unread
	case today
	case folder(Folder, Bool)
	case webFeed(WebFeed)
	case articleIDs(Set<String>)
	case search(String)
	case searchWithArticleIDs(String, Set<String>)
}

public final class Account: DisplayNameProvider, UnreadCountProvider, Container, Hashable {

    public struct UserInfoKey {
		public static let account = "account" // UserDidAddAccount, UserDidDeleteAccount
		public static let newArticles = "newArticles" // AccountDidDownloadArticles
		public static let updatedArticles = "updatedArticles" // AccountDidDownloadArticles
		public static let statuses = "statuses" // StatusesDidChange
		public static let articles = "articles" // StatusesDidChange
		public static let articleIDs = "articleIDs" // StatusesDidChange
		public static let webFeeds = "webFeeds" // AccountDidDownloadArticles, StatusesDidChange
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

	public var topLevelWebFeeds = Set<WebFeed>()
	public var folders: Set<Folder>? = Set<Folder>()
	
	public var sortedFolders: [Folder]? {
		if let folders = folders {
			return Array(folders).sorted(by: { $0.nameForDisplay < $1.nameForDisplay })
		}
		return nil
	}
	
	private var webFeedDictionaryNeedsUpdate = true
	private var _idToWebFeedDictionary = [String: WebFeed]()
	var idToWebFeedDictionary: [String: WebFeed] {
		if webFeedDictionaryNeedsUpdate {
			rebuildWebFeedDictionaries()
		}
		return _idToWebFeedDictionary
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
	static let saveQueue = CoalescingQueue(name: "Account Save Queue", interval: 1.0)

	private var unreadCounts = [String: Int]() // [feedID: Int]

	private var _flattenedWebFeeds = Set<WebFeed>()
	private var flattenedWebFeedsNeedUpdate = true

	private lazy var opmlFile = OPMLFile(filename: (dataFolder as NSString).appendingPathComponent("Subscriptions.opml"), account: self)
	private lazy var metadataFile = AccountMetadataFile(filename: (dataFolder as NSString).appendingPathComponent("Settings.plist"), account: self)
	var metadata = AccountMetadata() {
		didSet {
			delegate.accountMetadata = metadata
		}
	}

	private lazy var webFeedMetadataFile = WebFeedMetadataFile(filename: (dataFolder as NSString).appendingPathComponent("FeedMetadata.plist"), account: self)
	typealias WebFeedMetadataDictionary = [String: WebFeedMetadata]
	var webFeedMetadata = WebFeedMetadataDictionary()

	var startingUp = true

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
					opmlFile.markAsDirty()
				}
			}
		}
	}

	var refreshProgress: DownloadProgress {
		return delegate.refreshProgress
	}
	
	init?(dataFolder: String, type: AccountType, accountID: String, transport: Transport? = nil) {
		switch type {
		case .onMyMac:
			self.delegate = LocalAccountDelegate()
		case .feedbin:
			self.delegate = FeedbinAccountDelegate(dataFolder: dataFolder, transport: transport)
		case .freshRSS:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, transport: transport)
		case .feedly:
			self.delegate = FeedlyAccountDelegate(dataFolder: dataFolder, transport: transport, api: FeedlyAccountDelegate.environment)
		case .feedWrangler:
			self.delegate = FeedWranglerAccountDelegate(dataFolder: dataFolder, transport: transport)
		default:
			return nil
		}

		self.delegate.accountMetadata = metadata
		
		self.accountID = accountID
		self.type = type
		self.dataFolder = dataFolder

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("DB.sqlite3")
		self.database = ArticlesDatabase(databaseFilePath: databaseFilePath, accountID: accountID)

		switch type {
		case .onMyMac:
			defaultName = Account.defaultLocalAccountName
		case .feedly:
			defaultName = "Feedly"
		case .feedbin:
			defaultName = "Feedbin"
		case .feedWrangler:
			defaultName = "FeedWrangler"
		case .newsBlur:
			defaultName = "NewsBlur"
		case .freshRSS:
			defaultName = "FreshRSS"
		}

		NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressDidChange(_:)), name: .DownloadProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(childrenDidChange(_:)), name: .ChildrenDidChange, object: nil)

		metadataFile.load()
		webFeedMetadataFile.load()
		opmlFile.load()

		DispatchQueue.main.async {
			self.database.cleanupDatabaseAtStartup(subscribedToWebFeedIDs: self.flattenedWebFeeds().webFeedIDs())
			self.fetchAllUnreadCounts()
		}

		self.delegate.accountDidInitialize(self)
		startingUp = false
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
	
	public static func validateCredentials(transport: Transport = URLSession.webserviceTransport(), type: AccountType, credentials: Credentials, endpoint: URL? = nil, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		switch type {
		case .feedbin:
			FeedbinAccountDelegate.validateCredentials(transport: transport, credentials: credentials, completion: completion)
		case .freshRSS:
			ReaderAPIAccountDelegate.validateCredentials(transport: transport, credentials: credentials, endpoint: endpoint, completion: completion)
		case .feedWrangler:
			FeedWranglerAccountDelegate.validateCredentials(transport: transport, credentials: credentials, completion: completion)
		default:
			break
		}
	}
	
	internal static func oauthAuthorizationClient(for type: AccountType) -> OAuthAuthorizationClient {
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
											   accountType: AccountType,
											   transport: Transport = URLSession.webserviceTransport(),
											   completion: @escaping (Result<OAuthAuthorizationGrant, Error>) -> ()) {
		let grantingType: OAuthAuthorizationGranting.Type
		
		switch accountType {
		case .feedly:
			grantingType = FeedlyAccountDelegate.self
		default:
			fatalError("\(accountType) does not support OAuth authorization code granting.")
		}
		
		grantingType.requestOAuthAccessToken(with: response, transport: transport, completion: completion)
	}

	public func refreshAll(completion: @escaping (Result<Void, Error>) -> Void) {
		self.delegate.refreshAll(for: self, completion: completion)
	}

	public func syncArticleStatus(completion: ((Result<Void, Error>) -> Void)? = nil) {
		delegate.sendArticleStatus(for: self) { [unowned self] result in
			switch result {
			case .success:
				self.delegate.refreshArticleStatus(for: self) { result in
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
		database.suspend()
		save()
		metadataFile.suspend()
		webFeedMetadataFile.suspend()
		opmlFile.suspend()
	}

	/// Re-open the SQLite database and allow database calls.
	/// Call this *before* calling resume.
	public func resumeDatabaseAndDelegate() {
		database.resume()
		delegate.resume()
	}

	/// Reload OPML, etc.
	public func resume() {
		metadataFile.resume()
		webFeedMetadataFile.resume()
		opmlFile.resume()
		metadataFile.load()
		webFeedMetadataFile.load()
		opmlFile.load()
	}

	public func save() {
		metadataFile.save()
		webFeedMetadataFile.save()
		opmlFile.save()
	}
	
	public func prepareForDeletion() {
		delegate.accountWillBeDeleted(self)
	}
	
	func loadOPMLItems(_ items: [RSOPMLItem], parentFolder: Folder?) {
		var feedsToAdd = Set<WebFeed>()

		items.forEach { (item) in

			if let feedSpecifier = item.feedSpecifier {
				let feed = newWebFeed(with: feedSpecifier)
				feedsToAdd.insert(feed)
				return
			}

			guard let folderName = item.titleFromAttributes else {
				// Folder doesn’t have a name, so it won’t be created, and its items will go one level up.
				if let itemChildren = item.children {
					loadOPMLItems(itemChildren, parentFolder: parentFolder)
				}
				return
			}

			if let folder = ensureFolder(with: folderName) {
				folder.externalID = item.attributes?["nnw_externalID"] as? String
				if let itemChildren = item.children {
					loadOPMLItems(itemChildren, parentFolder: folder)
				}
			}
		}

		if let parentFolder = parentFolder {
			for feed in feedsToAdd {
				parentFolder.addWebFeed(feed)
			}
		} else {
			for feed in feedsToAdd {
				addWebFeed(feed)
			}
		}
		
	}
	
	public func resetWebFeedMetadataAndUnreadCounts() {
		for feed in flattenedWebFeeds() {
			feed.metadata = webFeedMetadata(feedURL: feed.url, webFeedID: feed.webFeedID)
		}
		fetchAllUnreadCounts()
		NotificationCenter.default.post(name: .WebFeedMetadataDidChange, object: self, userInfo: nil)
	}
	
	public func markArticles(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		return delegate.markArticles(for: self, articles: articles, statusKey: statusKey, flag: flag)
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

	public func findFolder(withDisplayName displayName: String) -> Folder? {
		return folders?.first(where: { $0.nameForDisplay == displayName })
	}
	
	func newWebFeed(with opmlFeedSpecifier: RSOPMLFeedSpecifier) -> WebFeed {
		let feedURL = opmlFeedSpecifier.feedURL
		let metadata = webFeedMetadata(feedURL: feedURL, webFeedID: feedURL)
		let feed = WebFeed(account: self, url: opmlFeedSpecifier.feedURL, metadata: metadata)
		if let feedTitle = opmlFeedSpecifier.title {
			if feed.name == nil {
				feed.name = feedTitle
			}
		}
		return feed
	}

	public func addWebFeed(_ feed: WebFeed, to container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.addWebFeed(for: self, with: feed, to: container, completion: completion)
	}

	public func createWebFeed(url: String, name: String?, container: Container, completion: @escaping (Result<WebFeed, Error>) -> Void) {
		delegate.createWebFeed(for: self, url: url, name: name, container: container, completion: completion)
	}
	
	func createWebFeed(with name: String?, url: String, webFeedID: String, homePageURL: String?) -> WebFeed {
		let metadata = webFeedMetadata(feedURL: url, webFeedID: webFeedID)
		let feed = WebFeed(account: self, url: url, metadata: metadata)
		feed.name = name
		feed.homePageURL = homePageURL
		
		return feed
	}
	
	public func removeWebFeed(_ feed: WebFeed, from container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.removeWebFeed(for: self, with: feed, from: container, completion: completion)
	}
	
	public func moveWebFeed(_ feed: WebFeed, from: Container, to: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.moveWebFeed(for: self, with: feed, from: from, to: to, completion: completion)
	}
	
	public func renameWebFeed(_ feed: WebFeed, to name: String, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.renameWebFeed(for: self, with: feed, to: name, completion: completion)
	}
	
	public func restoreWebFeed(_ feed: WebFeed, container: Container, completion: @escaping (Result<Void, Error>) -> Void) {
		delegate.restoreWebFeed(for: self, feed: feed, container: container, completion: completion)
	}
	
	public func addFolder(_ name: String, completion: @escaping (Result<Folder, Error>) -> Void) {
		delegate.addFolder(for: self, name: name, completion: completion)
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
	
	func clearWebFeedMetadata(_ feed: WebFeed) {
		webFeedMetadata[feed.url] = nil
	}
	
	func addFolder(_ folder: Folder) {
		folders!.insert(folder)
		postChildrenDidChangeNotification()
		structureDidChange()
	}
	
	public func updateUnreadCounts(for webFeeds: Set<WebFeed>, completion: VoidCompletionBlock? = nil) {
		if webFeeds.isEmpty {
			completion?()
			return
		}
		
		database.fetchUnreadCounts(for: webFeeds.webFeedIDs()) { unreadCountDictionaryResult in
			if let unreadCountDictionary = try? unreadCountDictionaryResult.get() {
				for webFeed in webFeeds {
					if let unreadCount = unreadCountDictionary[webFeed.webFeedID] {
						webFeed.unreadCount = unreadCount
					}
				}
			}

			completion?()
		}
	}

	public func fetchArticles(_ fetchType: FetchType) throws -> Set<Article> {
		switch fetchType {
		case .starred:
			return try fetchStarredArticles()
		case .unread:
			return try fetchUnreadArticles()
		case .today:
			return try fetchTodayArticles()
		case .folder(let folder, let readFilter):
			if readFilter {
				return try fetchUnreadArticles(folder: folder)
			} else {
				return try fetchArticles(folder: folder)
			}
		case .webFeed(let webFeed):
			return try fetchArticles(webFeed: webFeed)
		case .articleIDs(let articleIDs):
			return try fetchArticles(articleIDs: articleIDs)
		case .search(let searchString):
			return try fetchArticlesMatching(searchString)
		case .searchWithArticleIDs(let searchString, let articleIDs):
			return try fetchArticlesMatchingWithArticleIDs(searchString, articleIDs)
		}
	}

	public func fetchArticlesAsync(_ fetchType: FetchType, _ completion: @escaping ArticleSetResultBlock) {
		switch fetchType {
		case .starred:
			fetchStarredArticlesAsync(completion)
		case .unread:
			fetchUnreadArticlesAsync(completion)
		case .today:
			fetchTodayArticlesAsync(completion)
		case .folder(let folder, let readFilter):
			if readFilter {
				return fetchUnreadArticlesAsync(folder: folder, completion)
			} else {
				return fetchArticlesAsync(folder: folder, completion)
			}
		case .webFeed(let webFeed):
			fetchArticlesAsync(webFeed: webFeed, completion)
		case .articleIDs(let articleIDs):
			fetchArticlesAsync(articleIDs: articleIDs, completion)
		case .search(let searchString):
			fetchArticlesMatchingAsync(searchString, completion)
		case .searchWithArticleIDs(let searchString, let articleIDs):
			return fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, completion)
		}
	}

	public func fetchUnreadCountForToday(_ completion: @escaping SingleUnreadCountCompletionBlock) {
		database.fetchUnreadCountForToday(for: flattenedWebFeeds().webFeedIDs(), completion: completion)
	}

	public func fetchUnreadCountForStarredArticles(_ completion: @escaping SingleUnreadCountCompletionBlock) {
		database.fetchStarredAndUnreadCount(for: flattenedWebFeeds().webFeedIDs(), completion: completion)
	}

	public func fetchUnreadArticleIDs(_ completion: @escaping ArticleIDsCompletionBlock) {
		database.fetchUnreadArticleIDsAsync(webFeedIDs: flattenedWebFeeds().webFeedIDs(), completion: completion)
	}

	public func fetchStarredArticleIDs(_ completion: @escaping ArticleIDsCompletionBlock) {
		database.fetchStarredArticleIDsAsync(webFeedIDs: flattenedWebFeeds().webFeedIDs(), completion: completion)
	}

	/// Fetch articleIDs for articles that we should have, but don’t. These articles are not userDeleted, and they are either (starred) or (newer than the article cutoff date).
	public func fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(_ completion: @escaping ArticleIDsCompletionBlock) {
		database.fetchArticleIDsForStatusesWithoutArticlesNewerThanCutoffDate(completion)
	}
	
	public func unreadCount(for webFeed: WebFeed) -> Int {
		return unreadCounts[webFeed.webFeedID] ?? 0
	}

	public func setUnreadCount(_ unreadCount: Int, for webFeed: WebFeed) {
		unreadCounts[webFeed.webFeedID] = unreadCount
	}

	public func structureDidChange() {
		// Feeds were added or deleted. Or folders added or deleted.
		// Or feeds inside folders were added or deleted.
		if !startingUp {
			opmlFile.markAsDirty()
		}
		flattenedWebFeedsNeedUpdate = true
		webFeedDictionaryNeedsUpdate = true
	}

	func update(_ webFeed: WebFeed, with parsedFeed: ParsedFeed, _ completion: @escaping DatabaseCompletionBlock) {
		// Used only by an On My Mac account.
		webFeed.takeSettings(from: parsedFeed)
		let webFeedIDsAndItems = [webFeed.webFeedID: parsedFeed.items]
		update(webFeedIDsAndItems: webFeedIDsAndItems, defaultRead: false, completion: completion)
	}

	func update(webFeedIDsAndItems: [String: Set<ParsedItem>], defaultRead: Bool, completion: @escaping DatabaseCompletionBlock) {
		precondition(Thread.isMainThread)
		guard !webFeedIDsAndItems.isEmpty else {
			completion(nil)
			return
		}
		
		let group = DispatchGroup()
		var possibleError: DatabaseError? = nil
		var newArticles = Set<Article>()
		var updatedArticles = Set<Article>()
		
		for (webFeedID, items) in webFeedIDsAndItems {
			
			group.enter()
			database.update(webFeedID: webFeedID, items: items, defaultRead: defaultRead) { updateArticlesResult in

				switch updateArticlesResult {
				case .success(let newAndUpdatedArticles):
					if let articles = newAndUpdatedArticles.newArticles {
						newArticles.formUnion(articles)
					}
					if let articles = newAndUpdatedArticles.updatedArticles {
						updatedArticles.formUnion(articles)
					}
				case .failure(let databaseError):
					possibleError = databaseError
				}
				
				group.leave()
			}
			
		}
		
		group.notify(queue: DispatchQueue.main) {
			var userInfo = [String: Any]()
			var webFeeds = Set(newArticles.compactMap { $0.webFeed })
			webFeeds.formUnion(Set(updatedArticles.compactMap { $0.webFeed }))
			
			if !newArticles.isEmpty {
				self.updateUnreadCounts(for: webFeeds) {
					NotificationCenter.default.post(name: .DownloadArticlesDidUpdateUnreadCounts, object: self, userInfo: nil)
				}
				userInfo[UserInfoKey.newArticles] = newArticles
			}
			
			if !updatedArticles.isEmpty {
				userInfo[UserInfoKey.updatedArticles] = updatedArticles
			}
			
			userInfo[UserInfoKey.webFeeds] = webFeeds
			NotificationCenter.default.post(name: .AccountDidDownloadArticles, object: self, userInfo: userInfo)
			
			completion(possibleError)
		}
		
	}

	@discardableResult
	func update(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) throws -> Set<Article>? {
		// Returns set of Articles whose statuses did change.
		guard !articles.isEmpty, let updatedStatuses = try database.mark(articles, statusKey: statusKey, flag: flag) else {
			return nil
		}
		
		let updatedArticleIDs = updatedStatuses.articleIDs()
		let updatedArticles = Set(articles.filter{ updatedArticleIDs.contains($0.articleID) })
		
		noteStatusesForArticlesDidChange(updatedArticles)
		return updatedArticles
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
			if let error = error {
				completion?(error)
				return
			}
			self.noteStatusesForArticleIDsDidChange(articleIDs)
			completion?(nil)
		}
	}

	/// Mark articleIDs statuses based on statusKey and flag.
	/// Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	func mark(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, completion: DatabaseCompletionBlock? = nil) {
		guard !articleIDs.isEmpty else {
			completion?(nil)
			return
		}
		database.mark(articleIDs: articleIDs, statusKey: statusKey, flag: flag) { error in
			if let error = error {
				completion?(error)
				return
			}
			self.noteStatusesForArticleIDsDidChange(articleIDs)
			completion?(nil)
		}
	}

	/// Mark articleIDs as read. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	func markAsRead(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .read, flag: true, completion: completion)
	}

	/// Mark articleIDs as unread. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	func markAsUnread(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .read, flag: false, completion: completion)
	}

	/// Mark articleIDs as starred. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	func markAsStarred(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .starred, flag: true, completion: completion)
	}

	/// Mark articleIDs as unstarred. Will create statuses in the database and in memory as needed. Sends a .StatusesDidChange notification.
	func markAsUnstarred(_ articleIDs: Set<String>, completion: DatabaseCompletionBlock? = nil) {
		mark(articleIDs: articleIDs, statusKey: .starred, flag: false, completion: completion)
	}

	/// Empty caches that can reasonably be emptied. Call when the app goes in the background, for instance.
	func emptyCaches() {
		database.emptyCaches()
	}

	// MARK: - Container

	public func flattenedWebFeeds() -> Set<WebFeed> {
		assert(Thread.isMainThread)
		if flattenedWebFeedsNeedUpdate {
			updateFlattenedWebFeeds()
		}
		return _flattenedWebFeeds
	}

	public func removeWebFeed(_ webFeed: WebFeed) {
		topLevelWebFeeds.remove(webFeed)
		structureDidChange()
		postChildrenDidChangeNotification()
	}
	
	public func removeFeeds(_ webFeeds: Set<WebFeed>) {
		guard !webFeeds.isEmpty else {
			return
		}
		topLevelWebFeeds.subtract(webFeeds)
		structureDidChange()
		postChildrenDidChangeNotification()
	}
	
	public func addWebFeed(_ webFeed: WebFeed) {
		topLevelWebFeeds.insert(webFeed)
		structureDidChange()
		postChildrenDidChangeNotification()
	}

	func addFeedIfNotInAnyFolder(_ webFeed: WebFeed) {
		if !flattenedWebFeeds().contains(webFeed) {
			addWebFeed(webFeed)
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
			flattenedWebFeeds().forEach{ $0.debugDropConditionalGetInfo() }
		#endif
	}

	public func debugRunSearch() {
		#if DEBUG
			let t1 = Date()
			let articles = try! fetchArticlesMatching("Brent NetNewsWire")
			let t2 = Date()
			print(t2.timeIntervalSince(t1))
			print(articles.count)
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
	
	@objc func unreadCountDidChange(_ note: Notification) {
		if let feed = note.object as? WebFeed, feed.account === self {
			updateUnreadCount()
		}
	}
    
    @objc func batchUpdateDidPerform(_ note: Notification) {
		flattenedWebFeedsNeedUpdate = true
		rebuildWebFeedDictionaries()
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

	public class func ==(lhs: Account, rhs: Account) -> Bool {
		return lhs === rhs
	}
}

// MARK: - AccountMetadataDelegate

extension Account: AccountMetadataDelegate {
	func valueDidChange(_ accountMetadata: AccountMetadata, key: AccountMetadata.CodingKeys) {
		metadataFile.markAsDirty()
	}
}

// MARK: - FeedMetadataDelegate

extension Account: WebFeedMetadataDelegate {

	func valueDidChange(_ feedMetadata: WebFeedMetadata, key: WebFeedMetadata.CodingKeys) {
		webFeedMetadataFile.markAsDirty()
		guard let feed = existingWebFeed(withWebFeedID: feedMetadata.webFeedID) else {
			return
		}
		feed.postFeedSettingDidChangeNotification(key)
	}
}

// MARK: - Fetching (Private)

private extension Account {

	func fetchStarredArticles() throws -> Set<Article> {
		return try database.fetchStarredArticles(flattenedWebFeeds().webFeedIDs())
	}

	func fetchStarredArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		database.fetchedStarredArticlesAsync(flattenedWebFeeds().webFeedIDs(), completion)
	}

	func fetchUnreadArticles() throws -> Set<Article> {
		return try fetchUnreadArticles(forContainer: self)
	}

	func fetchUnreadArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		fetchUnreadArticlesAsync(forContainer: self, completion)
	}

	func fetchTodayArticles() throws -> Set<Article> {
		return try database.fetchTodayArticles(flattenedWebFeeds().webFeedIDs())
	}

	func fetchTodayArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {
		database.fetchTodayArticlesAsync(flattenedWebFeeds().webFeedIDs(), completion)
	}

	func fetchArticles(folder: Folder) throws -> Set<Article> {
		return try fetchArticles(forContainer: folder)
	}

	func fetchArticlesAsync(folder: Folder, _ completion: @escaping ArticleSetResultBlock) {
		fetchArticlesAsync(forContainer: folder, completion)
	}

	func fetchUnreadArticles(folder: Folder) throws -> Set<Article> {
		return try fetchUnreadArticles(forContainer: folder)
	}

	func fetchUnreadArticlesAsync(folder: Folder, _ completion: @escaping ArticleSetResultBlock) {
		fetchUnreadArticlesAsync(forContainer: folder, completion)
	}

	func fetchArticles(webFeed: WebFeed) throws -> Set<Article> {
		let articles = try database.fetchArticles(webFeed.webFeedID)
		validateUnreadCount(webFeed, articles)
		return articles
	}

	func fetchArticlesAsync(webFeed: WebFeed, _ completion: @escaping ArticleSetResultBlock) {
		database.fetchArticlesAsync(webFeed.webFeedID) { [weak self] articleSetResult in
			switch articleSetResult {
			case .success(let articles):
				self?.validateUnreadCount(webFeed, articles)
				completion(.success(articles))
			case .failure(let databaseError):
				completion(.failure(databaseError))
			}
		}
	}

	func fetchArticlesMatching(_ searchString: String) throws -> Set<Article> {
		return try database.fetchArticlesMatching(searchString, flattenedWebFeeds().webFeedIDs())
	}

	func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>) throws -> Set<Article> {
		return try database.fetchArticlesMatchingWithArticleIDs(searchString, articleIDs)
	}
	
	func fetchArticlesMatchingAsync(_ searchString: String, _ completion: @escaping ArticleSetResultBlock) {
		database.fetchArticlesMatchingAsync(searchString, flattenedWebFeeds().webFeedIDs(), completion)
	}

	func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		database.fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, completion)
	}

	func fetchArticles(articleIDs: Set<String>) throws -> Set<Article> {
		return try database.fetchArticles(articleIDs: articleIDs)
	}

	func fetchArticlesAsync(articleIDs: Set<String>, _ completion: @escaping ArticleSetResultBlock) {
		return database.fetchArticlesAsync(articleIDs: articleIDs, completion)
	}

	func fetchUnreadArticles(webFeed: WebFeed) throws -> Set<Article> {
		let articles = try database.fetchUnreadArticles(Set([webFeed.webFeedID]))
		validateUnreadCount(webFeed, articles)
		return articles
	}

	func fetchUnreadArticlesAsync(for webFeed: WebFeed, completion: @escaping (Set<Article>) -> Void) {
		//		database.fetchUnreadArticlesAsync(for: Set([feed.feedID])) { [weak self] (articles) in
		//			self?.validateUnreadCount(feed, articles)
		//			callback(articles)
		//		}
	}


	func fetchArticles(forContainer container: Container) throws -> Set<Article> {
		let feeds = container.flattenedWebFeeds()
		let articles = try database.fetchArticles(feeds.webFeedIDs())
		validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)
		return articles
	}

	func fetchArticlesAsync(forContainer container: Container, _ completion: @escaping ArticleSetResultBlock) {
		let webFeeds = container.flattenedWebFeeds()
		database.fetchArticlesAsync(webFeeds.webFeedIDs()) { [weak self] (articleSetResult) in
			switch articleSetResult {
			case .success(let articles):
				self?.validateUnreadCountsAfterFetchingUnreadArticles(webFeeds, articles)
				completion(.success(articles))
			case .failure(let databaseError):
				completion(.failure(databaseError))
			}
		}
	}

	func fetchUnreadArticles(forContainer container: Container) throws -> Set<Article> {
		let feeds = container.flattenedWebFeeds()
		let articles = try database.fetchUnreadArticles(feeds.webFeedIDs())
		validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)
		return articles
	}

	func fetchUnreadArticlesAsync(forContainer container: Container, _ completion: @escaping ArticleSetResultBlock) {
		let webFeeds = container.flattenedWebFeeds()
		database.fetchUnreadArticlesAsync(webFeeds.webFeedIDs()) { [weak self] (articleSetResult) in
			switch articleSetResult {
			case .success(let articles):
				self?.validateUnreadCountsAfterFetchingUnreadArticles(webFeeds, articles)
				completion(.success(articles))
			case .failure(let databaseError):
				completion(.failure(databaseError))
			}
		}
	}

	func validateUnreadCountsAfterFetchingUnreadArticles(_ webFeeds: Set<WebFeed>, _ articles: Set<Article>) {
		// Validate unread counts. This was the site of a performance slowdown:
		// it was calling going through the entire list of articles once per feed:
		// feeds.forEach { validateUnreadCount($0, articles) }
		// Now we loop through articles exactly once. This makes a huge difference.

		var unreadCountStorage = [String: Int]() // [WebFeedID: Int]
		for article in articles where !article.status.read {
			unreadCountStorage[article.webFeedID, default: 0] += 1
		}
		webFeeds.forEach { (webFeed) in
			let unreadCount = unreadCountStorage[webFeed.webFeedID, default: 0]
			webFeed.unreadCount = unreadCount
		}
	}

	func validateUnreadCount(_ webFeed: WebFeed, _ articles: Set<Article>) {
		// articles must contain all the unread articles for the feed.
		// The unread number should match the feed’s unread count.

		let feedUnreadCount = articles.reduce(0) { (result, article) -> Int in
			if article.webFeed == webFeed && !article.status.read {
				return result + 1
			}
			return result
		}

		webFeed.unreadCount = feedUnreadCount
	}
}

// MARK: - Private

private extension Account {

	func webFeedMetadata(feedURL: String, webFeedID: String) -> WebFeedMetadata {
		if let d = webFeedMetadata[feedURL] {
			assert(d.delegate === self)
			return d
		}
		let d = WebFeedMetadata(webFeedID: webFeedID)
		d.delegate = self
		webFeedMetadata[feedURL] = d
		return d
	}

	func updateFlattenedWebFeeds() {
		var feeds = Set<WebFeed>()
		feeds.formUnion(topLevelWebFeeds)
		for folder in folders! {
			feeds.formUnion(folder.flattenedWebFeeds())
		}

		_flattenedWebFeeds = feeds
		flattenedWebFeedsNeedUpdate = false
	}

	func rebuildWebFeedDictionaries() {
		var idDictionary = [String: WebFeed]()

		flattenedWebFeeds().forEach { (feed) in
			idDictionary[feed.webFeedID] = feed
		}

		_idToWebFeedDictionary = idDictionary
		webFeedDictionaryNeedsUpdate = false
	}
    
    func updateUnreadCount() {
		if fetchingAllUnreadCounts {
			return
		}
		var updatedUnreadCount = 0
		for feed in flattenedWebFeeds() {
			updatedUnreadCount += feed.unreadCount
		}
		unreadCount = updatedUnreadCount
    }
    
    func noteStatusesForArticlesDidChange(_ articles: Set<Article>) {
		let feeds = Set(articles.compactMap { $0.webFeed })
		let statuses = Set(articles.map { $0.status })
		let articleIDs = Set(articles.map { $0.articleID })

        // .UnreadCountDidChange notification will get sent to Folder and Account objects,
        // which will update their own unread counts.
        updateUnreadCounts(for: feeds)
        
		NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.statuses: statuses, UserInfoKey.articles: articles, UserInfoKey.articleIDs: articleIDs, UserInfoKey.webFeeds: feeds])
    }

	func noteStatusesForArticleIDsDidChange(_ articleIDs: Set<String>) {
		fetchAllUnreadCounts()
		NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.articleIDs: articleIDs])
	}

	func fetchAllUnreadCounts() {
		fetchingAllUnreadCounts = true

		database.fetchAllNonZeroUnreadCounts { (unreadCountDictionaryResult) in
			if let unreadCountDictionary = try? unreadCountDictionaryResult.get() {
				self.flattenedWebFeeds().forEach{ (feed) in
					// When the unread count is zero, it won’t appear in unreadCountDictionary.
					if let unreadCount = unreadCountDictionary[feed.webFeedID] {
						feed.unreadCount = unreadCount
					}
					else {
						feed.unreadCount = 0
					}
				}

				self.fetchingAllUnreadCounts = false
				self.updateUnreadCount()
				self.isUnreadCountsInitialized = true
				self.postUnreadCountDidInitializeNotification()
			}
		}
	}
}

// MARK: - Container Overrides

extension Account {

	public func existingWebFeed(withWebFeedID webFeedID: String) -> WebFeed? {
		return idToWebFeedDictionary[webFeedID]
	}
}

// MARK: - OPMLRepresentable

extension Account: OPMLRepresentable {

	public func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String {
		var s = ""
		for feed in topLevelWebFeeds.sorted() {
			s += feed.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
		}
		for folder in folders!.sorted() {
			s += folder.OPMLString(indentLevel: indentLevel + 1, allowCustomAttributes: allowCustomAttributes)
		}
		return s
	}
}
