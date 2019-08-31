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
import ArticlesDatabase
import RSWeb
import os.log

// Main thread only.

public extension Notification.Name {
	static let AccountRefreshDidBegin = Notification.Name(rawValue: "AccountRefreshDidBegin")
	static let AccountRefreshDidFinish = Notification.Name(rawValue: "AccountRefreshDidFinish")
	static let AccountRefreshProgressDidChange = Notification.Name(rawValue: "AccountRefreshProgressDidChange")
	static let AccountDidDownloadArticles = Notification.Name(rawValue: "AccountDidDownloadArticles")
	static let AccountStateDidChange = Notification.Name(rawValue: "AccountStateDidChange")
	static let StatusesDidChange = Notification.Name(rawValue: "StatusesDidChange")
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
	case unreadForFolder(Folder)
	case feed(Feed)
	case articleIDs(Set<String>)
	case search(String)
	case searchWithArticleIDs(String, Set<String>)
}

public final class Account: DisplayNameProvider, UnreadCountProvider, Container, Hashable {

    public struct UserInfoKey {
		public static let newArticles = "newArticles" // AccountDidDownloadArticles
		public static let updatedArticles = "updatedArticles" // AccountDidDownloadArticles
		public static let statuses = "statuses" // StatusesDidChange
		public static let articles = "articles" // StatusesDidChange
		public static let feeds = "feeds" // AccountDidDownloadArticles, StatusesDidChange
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
				NotificationCenter.default.post(name: .AccountStateDidChange, object: self, userInfo: nil)
			}
		}
	}

	public var topLevelFeeds = Set<Feed>()
	public var folders: Set<Folder>? = Set<Folder>()
	private var feedDictionaryNeedsUpdate = true
	private var _idToFeedDictionary = [String: Feed]()
	var idToFeedDictionary: [String: Feed] {
		if feedDictionaryNeedsUpdate {
			rebuildFeedDictionaries()
		}
		return _idToFeedDictionary
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
	private let opmlFilePath: String

	private var _flattenedFeeds = Set<Feed>()
	private var flattenedFeedsNeedUpdate = true

	private let metadataPath: String
	var metadata = AccountMetadata()
	private var metadataDirty = false {
		didSet {
			queueSaveAccountMetadatafNeeded()
		}
	}

	private let feedMetadataPath: String
	private typealias FeedMetadataDictionary = [String: FeedMetadata]
	private var feedMetadata = FeedMetadataDictionary()
	private var feedMetadataDirty = false {
		didSet {
			queueSaveFeedMetadataIfNeeded()
		}
	}

	private var startingUp = true

	public var dirty = false {
		didSet {
			queueSaveToDiskIfNeeded()
		}
	}

    public var unreadCount = 0 {
        didSet {
            if unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }
    
	public var isTagBasedSystem: Bool {
		return delegate.isTagBasedSystem
	}
	
	public var isOPMLImportSupported: Bool {
		return delegate.isOPMLImportSupported
	}
	
	var refreshInProgress = false {
		didSet {
			if refreshInProgress != oldValue {
				if refreshInProgress {
					NotificationCenter.default.post(name: .AccountRefreshDidBegin, object: self)
				}
				else {
					NotificationCenter.default.post(name: .AccountRefreshDidFinish, object: self)
					queueSaveToDiskIfNeeded()
				}
			}
		}
	}

	var refreshProgress: DownloadProgress {
		return delegate.refreshProgress
	}
	
	var isSubfoldersSupported: Bool {
		return delegate.isSubfoldersSupported
	}
	
	init?(dataFolder: String, type: AccountType, accountID: String, transport: Transport? = nil) {
		switch type {
		case .onMyMac:
			self.delegate = LocalAccountDelegate()
		case .feedbin:
			self.delegate = FeedbinAccountDelegate(dataFolder: dataFolder, transport: transport)
		case .freshRSS:
			self.delegate = ReaderAPIAccountDelegate(dataFolder: dataFolder, transport: transport)
		default:
			fatalError("Only Local and Feedbin accounts are supported")
		}

		self.accountID = accountID
		self.type = type
		self.dataFolder = dataFolder

		self.opmlFilePath = (dataFolder as NSString).appendingPathComponent("Subscriptions.opml")

		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("DB.sqlite3")
		self.database = ArticlesDatabase(databaseFilePath: databaseFilePath, accountID: accountID)

		self.feedMetadataPath = (dataFolder as NSString).appendingPathComponent("FeedMetadata.plist")
		self.metadataPath = (dataFolder as NSString).appendingPathComponent("Settings.plist")

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

		pullObjectsFromDisk()
		
		DispatchQueue.main.async {
			self.fetchAllUnreadCounts()
		}

		self.delegate.accountDidInitialize(self)
		startingUp = false
	}
	
	// MARK: - API
	
	public func storeCredentials(_ credentials: Credentials) throws {
		guard let server = delegate.server else {
			throw CredentialsError.incompleteCredentials
		}
		
		switch credentials {
		case .basic(let username, _):
			self.username = username
		case .readerAPIBasicLogin(let username, _):
			self.username = username
		case .readerAPIAuthLogin(let username, _):
			self.username = username
		}
		
		try CredentialsManager.storeCredentials(credentials, server: server)
		
		delegate.credentials = credentials
	}
	
	public func retrieveCredentials() throws -> Credentials? {
		switch type {
		case .feedbin:
			guard let username = self.username, let server = delegate.server else {
				return nil
			}
			return try CredentialsManager.retrieveBasicCredentials(server: server, username: username)
		case .freshRSS:
			guard let username = self.username, let server = delegate.server else {
				return nil
			}
			return try CredentialsManager.retrieveReaderAPIAuthCredentials(server: server, username: username)
		default:
			return nil
		}
	}
	
	public func removeCredentials() throws {
		switch type {
		case .feedbin:
			guard let username = self.username, let server = delegate.server else {
				return
			}
			try CredentialsManager.removeBasicCredentials(server: server, username: username)
			self.username = nil
		case .freshRSS:
			guard let username = self.username, let server = delegate.server else {
				return
			}
			try CredentialsManager.removeReaderAPIAuthCredentials(server: server, username: username)
			self.username = nil
		default:
			break
		}
	}
	
	public static func validateCredentials(transport: Transport = URLSession.webserviceTransport(), type: AccountType, credentials: Credentials, endpoint: URL? = nil, completion: @escaping (Result<Credentials?, Error>) -> Void) {
		switch type {
		case .onMyMac:
			LocalAccountDelegate.validateCredentials(transport: transport, credentials: credentials, completion: completion)
		case .feedbin:
			FeedbinAccountDelegate.validateCredentials(transport: transport, credentials: credentials, completion: completion)
		case .freshRSS:
			ReaderAPIAccountDelegate.validateCredentials(transport: transport, credentials: credentials, endpoint: endpoint, completion: completion)
		default:
			break
		}
	}

	public func refreshAll(completion: @escaping (Result<Void, Error>) -> Void) {
		self.delegate.refreshAll(for: self, completion: completion)
	}

	public func syncArticleStatus(completion: (() -> Void)? = nil) {
		delegate.sendArticleStatus(for: self) { [unowned self] in
			self.delegate.refreshArticleStatus(for: self) {
				completion?()
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
				self.metadata.lastArticleFetch = nil
				self.delegate.refreshAll(for: self, completion: completion)
			case .failure(let error):
				completion(.failure(error))
			}
		}
		
	}
	
	public func markArticles(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		return delegate.markArticles(for: self, articles: articles, statusKey: statusKey, flag: flag)
	}

	@discardableResult
	public func ensureFolder(with name: String) -> Folder? {
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

	public func createFeed(url: String, name: String?, container: Container, completion: @escaping (Result<Feed, Error>) -> Void) {
		delegate.createFeed(for: self, url: url, name: name, container: container, completion: completion)
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
	
	func clearFeedMetadata(_ feed: Feed) {
		feedMetadata[feed.url] = nil
	}
	
	func addFolder(_ folder: Folder) {
		folders!.insert(folder)
		postChildrenDidChangeNotification()
		structureDidChange()
	}
	
	func loadOPML(_ opmlDocument: RSOPMLDocument) {
		guard let children = opmlDocument.children else {
			return
		}
		loadOPMLItems(children, parentFolder: nil)
		structureDidChange()

		DispatchQueue.main.async {
			self.refreshAll() { result in }
		}
		
	}

	public func updateUnreadCounts(for feeds: Set<Feed>) {
		if feeds.isEmpty {
			return
		}
		
		database.fetchUnreadCounts(for: feeds.feedIDs()) { (unreadCountDictionary) in
			for feed in feeds {
				if let unreadCount = unreadCountDictionary[feed.feedID] {
					feed.unreadCount = unreadCount
				}
			}
		}
	}

	public func fetchArticles(_ fetchType: FetchType) -> Set<Article> {
		switch fetchType {
		case .starred:
			return fetchStarredArticles()
		case .unread:
			return fetchUnreadArticles()
		case .today:
			return fetchTodayArticles()
		case .unreadForFolder(let folder):
			return fetchArticles(folder: folder)
		case .feed(let feed):
			return fetchArticles(feed: feed)
		case .articleIDs(let articleIDs):
			return fetchArticles(articleIDs: articleIDs)
		case .search(let searchString):
			return fetchArticlesMatching(searchString)
		case .searchWithArticleIDs(let searchString, let articleIDs):
			return fetchArticlesMatchingWithArticleIDs(searchString, articleIDs)
		}
	}

	public func fetchArticlesAsync(_ fetchType: FetchType, _ callback: @escaping ArticleSetBlock) {
		switch fetchType {
		case .starred:
			fetchStarredArticlesAsync(callback)
		case .unread:
			fetchUnreadArticlesAsync(callback)
		case .today:
			fetchTodayArticlesAsync(callback)
		case .unreadForFolder(let folder):
			fetchArticlesAsync(folder: folder, callback)
		case .feed(let feed):
			fetchArticlesAsync(feed: feed, callback)
		case .articleIDs(let articleIDs):
			fetchArticlesAsync(articleIDs: articleIDs, callback)
		case .search(let searchString):
			fetchArticlesMatchingAsync(searchString, callback)
		case .searchWithArticleIDs(let searchString, let articleIDs):
			return fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, callback)
		}
	}

	public func fetchUnreadCountForToday(_ callback: @escaping (Int) -> Void) {
		database.fetchUnreadCountForToday(for: flattenedFeeds().feedIDs(), callback: callback)
	}

	public func fetchUnreadCountForStarredArticles(_ callback: @escaping (Int) -> Void) {
		database.fetchStarredAndUnreadCount(for: flattenedFeeds().feedIDs(), callback: callback)
	}

	public func fetchUnreadArticleIDs() -> Set<String> {
		return database.fetchUnreadArticleIDs()
	}

	public func fetchStarredArticleIDs() -> Set<String> {
		return database.fetchStarredArticleIDs()
	}
	
	public func fetchArticleIDsForStatusesWithoutArticles() -> Set<String> {
		return database.fetchArticleIDsForStatusesWithoutArticles()
	}

	public func opmlDocument() -> String {
		let escapedTitle = nameForDisplay.rs_stringByEscapingSpecialXMLCharacters()
		let openingText =
		"""
		<?xml version="1.0" encoding="UTF-8"?>
		<!-- OPML generated by NetNewsWire -->
		<opml version="1.1">
		<head>
		<title>\(escapedTitle)</title>
		</head>
		<body>

		"""

		let middleText = OPMLString(indentLevel: 0)

		let closingText =
		"""
				</body>
			</opml>
			"""

		let opml = openingText + middleText + closingText
		return opml
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
		if !startingUp {
			dirty = true
		}
		flattenedFeedsNeedUpdate = true
		feedDictionaryNeedsUpdate = true
	}

	func update(_ feed: Feed, with parsedFeed: ParsedFeed, _ completion: @escaping (() -> Void)) {
		feed.takeSettings(from: parsedFeed)
		update(feed, parsedItems: parsedFeed.items, completion)
	}
	
	func update(_ feed: Feed, parsedItems: Set<ParsedItem>, defaultRead: Bool = false, _ completion: @escaping (() -> Void)) {
		database.update(feedID: feed.feedID, parsedItems: parsedItems, defaultRead: defaultRead) { (newArticles, updatedArticles) in
			var userInfo = [String: Any]()
			if let newArticles = newArticles, !newArticles.isEmpty {
				self.updateUnreadCounts(for: Set([feed]))
				userInfo[UserInfoKey.newArticles] = newArticles
			}
			if let updatedArticles = updatedArticles, !updatedArticles.isEmpty {
				userInfo[UserInfoKey.updatedArticles] = updatedArticles
			}
			userInfo[UserInfoKey.feeds] = Set([feed])
			
			completion()
			
			NotificationCenter.default.post(name: .AccountDidDownloadArticles, object: self, userInfo: userInfo)
		}
	}

	@discardableResult
	func update(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) -> Set<Article>? {
		// Returns set of Articles whose statuses did change.
		guard !articles.isEmpty, let updatedStatuses = database.mark(articles, statusKey: statusKey, flag: flag) else {
			return nil
		}
		
		let updatedArticleIDs = updatedStatuses.articleIDs()
		let updatedArticles = Set(articles.filter{ updatedArticleIDs.contains($0.articleID) })
		
		noteStatusesForArticlesDidChange(updatedArticles)
		return updatedArticles
	}

	func ensureStatuses(_ articleIDs: Set<String>, _ defaultRead: Bool, _ statusKey: ArticleStatus.Key, _ flag: Bool) {
		if !articleIDs.isEmpty {
			database.ensureStatuses(articleIDs, defaultRead, statusKey, flag)
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
			flattenedFeeds().forEach{ $0.debugDropConditionalGetInfo() }
		#endif
	}

	public func debugRunSearch() {
		#if DEBUG
			let t1 = Date()
			let articles = fetchArticlesMatching("Brent NetNewsWire")
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

	@objc func saveToDiskIfNeeded() {
		if dirty && !isDeleted {
			saveToDisk()
		}
	}

	@objc func saveFeedMetadataIfNeeded() {
		if feedMetadataDirty && !isDeleted {
			saveFeedMetadata()
		}
	}

	@objc func saveAccountMetadataIfNeeded() {
		if metadataDirty && !isDeleted {
			saveAccountMetadata()
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
		metadataDirty = true
	}
}

// MARK: - FeedMetadataDelegate

extension Account: FeedMetadataDelegate {

	func valueDidChange(_ feedMetadata: FeedMetadata, key: FeedMetadata.CodingKeys) {
		feedMetadataDirty = true
		guard let feed = existingFeed(with: feedMetadata.feedID) else {
			return
		}
		feed.postFeedSettingDidChangeNotification(key)
	}
}

// MARK: - Fetching (Private)

private extension Account {

	func fetchStarredArticles() -> Set<Article> {
		return database.fetchStarredArticles(flattenedFeeds().feedIDs())
	}

	func fetchStarredArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		database.fetchedStarredArticlesAsync(flattenedFeeds().feedIDs(), callback)
	}

	func fetchUnreadArticles() -> Set<Article> {
		return fetchUnreadArticles(forContainer: self)
	}

	func fetchUnreadArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		fetchUnreadArticlesAsync(forContainer: self, callback)
	}

	func fetchTodayArticles() -> Set<Article> {
		return database.fetchTodayArticles(flattenedFeeds().feedIDs())
	}

	func fetchTodayArticlesAsync(_ callback: @escaping ArticleSetBlock) {
		database.fetchTodayArticlesAsync(flattenedFeeds().feedIDs(), callback)
	}

	func fetchArticles(folder: Folder) -> Set<Article> {
		return fetchUnreadArticles(forContainer: folder)
	}

	func fetchArticlesAsync(folder: Folder, _ callback: @escaping ArticleSetBlock) {
		fetchUnreadArticlesAsync(forContainer: folder, callback)
	}

	func fetchArticles(feed: Feed) -> Set<Article> {
		let articles = database.fetchArticles(feed.feedID)
		validateUnreadCount(feed, articles)
		return articles
	}

	func fetchArticlesAsync(feed: Feed, _ callback: @escaping ArticleSetBlock) {
		database.fetchArticlesAsync(feed.feedID) { [weak self] (articles) in
			self?.validateUnreadCount(feed, articles)
			callback(articles)
		}
	}

	func fetchArticlesMatching(_ searchString: String) -> Set<Article> {
		return database.fetchArticlesMatching(searchString, flattenedFeeds().feedIDs())
	}

	func fetchArticlesMatchingWithArticleIDs(_ searchString: String, _ articleIDs: Set<String>) -> Set<Article> {
		return database.fetchArticlesMatchingWithArticleIDs(searchString, articleIDs)
	}
	
	func fetchArticlesMatchingAsync(_ searchString: String, _ callback: @escaping ArticleSetBlock) {
		database.fetchArticlesMatchingAsync(searchString, flattenedFeeds().feedIDs(), callback)
	}

	func fetchArticlesMatchingWithArticleIDsAsync(_ searchString: String, _ articleIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		database.fetchArticlesMatchingWithArticleIDsAsync(searchString, articleIDs, callback)
	}

	func fetchArticles(articleIDs: Set<String>) -> Set<Article> {
		return database.fetchArticles(articleIDs: articleIDs)
	}

	func fetchArticlesAsync(articleIDs: Set<String>, _ callback: @escaping ArticleSetBlock) {
		return database.fetchArticlesAsync(articleIDs: articleIDs, callback)
	}

	func fetchUnreadArticles(feed: Feed) -> Set<Article> {
		let articles = database.fetchUnreadArticles(Set([feed.feedID]))
		validateUnreadCount(feed, articles)
		return articles
	}

	func fetchUnreadArticlesAsync(for feed: Feed, callback: @escaping (Set<Article>) -> Void) {
		//		database.fetchUnreadArticlesAsync(for: Set([feed.feedID])) { [weak self] (articles) in
		//			self?.validateUnreadCount(feed, articles)
		//			callback(articles)
		//		}
	}


	func fetchUnreadArticles(forContainer container: Container) -> Set<Article> {
		let feeds = container.flattenedFeeds()
		let articles = database.fetchUnreadArticles(feeds.feedIDs())
		validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)
		return articles
	}

	func fetchUnreadArticlesAsync(forContainer container: Container, _ callback: @escaping ArticleSetBlock) {
		let feeds = container.flattenedFeeds()
		database.fetchUnreadArticlesAsync(feeds.feedIDs()) { [weak self] (articles) in
			self?.validateUnreadCountsAfterFetchingUnreadArticles(feeds, articles)
			callback(articles)
		}
	}

	func validateUnreadCountsAfterFetchingUnreadArticles(_ feeds: Set<Feed>, _ articles: Set<Article>) {
		// Validate unread counts. This was the site of a performance slowdown:
		// it was calling going through the entire list of articles once per feed:
		// feeds.forEach { validateUnreadCount($0, articles) }
		// Now we loop through articles exactly once. This makes a huge difference.

		var unreadCountStorage = [String: Int]() // [FeedID: Int]
		for article in articles where !article.status.read {
			unreadCountStorage[article.feedID, default: 0] += 1
		}
		feeds.forEach { (feed) in
			let unreadCount = unreadCountStorage[feed.feedID, default: 0]
			feed.unreadCount = unreadCount
		}
	}

	func validateUnreadCount(_ feed: Feed, _ articles: Set<Article>) {
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

// MARK: - Disk (Private)

private extension Account {
	
	func queueSaveToDiskIfNeeded() {
		Account.saveQueue.add(self, #selector(saveToDiskIfNeeded))
	}

	func pullObjectsFromDisk() {
		loadAccountMetadata()
		loadFeedMetadata()
		loadOPMLFile(path: opmlFilePath)
	}

	func loadAccountMetadata() {
		let url = URL(fileURLWithPath: metadataPath)
		guard let data = try? Data(contentsOf: url) else {
			metadata.delegate = self
			return
		}
		let decoder = PropertyListDecoder()
		metadata = (try? decoder.decode(AccountMetadata.self, from: data)) ?? AccountMetadata()
		metadata.delegate = self
	}

	func loadFeedMetadata() {
		let url = URL(fileURLWithPath: feedMetadataPath)
		guard let data = try? Data(contentsOf: url) else {
			return
		}
		let decoder = PropertyListDecoder()
		feedMetadata = (try? decoder.decode(FeedMetadataDictionary.self, from: data)) ?? FeedMetadataDictionary()
		feedMetadata.values.forEach { $0.delegate = self }
	}

	func loadOPMLFile(path: String) {
		let opmlFileURL = URL(fileURLWithPath: path)
		var fileData: Data?
		do {
			fileData = try Data(contentsOf: opmlFileURL)
		} catch {
			// Commented out because it’s not an error on first run.
			// TODO: make it so we know if it’s first run or not.
			//NSApplication.shared.presentError(error)
			return
		}
		guard let opmlData = fileData else {
			return
		}

		let parserData = ParserData(url: opmlFileURL.absoluteString, data: opmlData)
		var opmlDocument: RSOPMLDocument?

		do {
			opmlDocument = try RSOPMLParser.parseOPML(with: parserData)
		} catch {
			os_log(.error, log: log, "OPML Import failed: %@.", error.localizedDescription)
			return
		}
		guard let parsedOPML = opmlDocument, let children = parsedOPML.children else {
			return
		}

		BatchUpdate.shared.perform {
			loadOPMLItems(children, parentFolder: nil)
		}
	}

	func saveToDisk() {
		dirty = false

		let opmlDocumentString = opmlDocument()
		do {
			let url = URL(fileURLWithPath: opmlFilePath)
			try opmlDocumentString.write(to: url, atomically: true, encoding: .utf8)
		}
		catch let error as NSError {
			os_log(.error, log: log, "Save to disk failed: %@.", error.localizedDescription)
		}
	}

	func queueSaveFeedMetadataIfNeeded() {
		Account.saveQueue.add(self, #selector(saveFeedMetadataIfNeeded))
	}

	private func metadataForOnlySubscribedToFeeds() -> FeedMetadataDictionary {
		let feedIDs = idToFeedDictionary.keys
		return feedMetadata.filter { (feedID: String, metadata: FeedMetadata) -> Bool in
			return feedIDs.contains(metadata.feedID)
		}
	}

	func saveFeedMetadata() {
		feedMetadataDirty = false

		let d = metadataForOnlySubscribedToFeeds()
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: feedMetadataPath)
		do {
			let data = try encoder.encode(d)
			try data.write(to: url)
		}
		catch {
			assertionFailure(error.localizedDescription)
		}
	}

	func queueSaveAccountMetadatafNeeded() {
		Account.saveQueue.add(self, #selector(saveAccountMetadataIfNeeded))
	}

	func saveAccountMetadata() {
		metadataDirty = false

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let url = URL(fileURLWithPath: metadataPath)
		do {
			let data = try encoder.encode(metadata)
			try data.write(to: url)
		}
		catch {
			assertionFailure(error.localizedDescription)
		}
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

	func rebuildFeedDictionaries() {
		var idDictionary = [String: Feed]()

		flattenedFeeds().forEach { (feed) in
			idDictionary[feed.feedID] = feed
		}

		_idToFeedDictionary = idDictionary
		feedDictionaryNeedsUpdate = false
	}

	func loadOPMLItems(_ items: [RSOPMLItem], parentFolder: Folder?) {
		var feedsToAdd = Set<Feed>()

		items.forEach { (item) in

			if let feedSpecifier = item.feedSpecifier {
				let feed = newFeed(with: feedSpecifier)
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
				if let itemChildren = item.children {
					loadOPMLItems(itemChildren, parentFolder: folder)
				}
			}
		}

		if let parentFolder = parentFolder {
			for feed in feedsToAdd {
				parentFolder.addFeed(feed)
			}
		} else {
			for feed in feedsToAdd {
				addFeed(feed)
			}
		}
		
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
    
    func noteStatusesForArticlesDidChange(_ articles: Set<Article>) {
		let feeds = Set(articles.compactMap { $0.feed })
		let statuses = Set(articles.map { $0.status })
        
        // .UnreadCountDidChange notification will get sent to Folder and Account objects,
        // which will update their own unread counts.
        updateUnreadCounts(for: feeds)
        
        NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.statuses: statuses, UserInfoKey.articles: articles, UserInfoKey.feeds: feeds])
    }

	func fetchAllUnreadCounts() {
		fetchingAllUnreadCounts = true

		database.fetchAllNonZeroUnreadCounts { (unreadCountDictionary) in
			if unreadCountDictionary.isEmpty {
				self.fetchingAllUnreadCounts = false
				self.updateUnreadCount()
				self.isUnreadCountsInitialized = true
				return
			}

			self.flattenedFeeds().forEach{ (feed) in
				// When the unread count is zero, it won’t appear in unreadCountDictionary.

				if let unreadCount = unreadCountDictionary[feed.feedID] {
					feed.unreadCount = unreadCount
				}
				else {
					feed.unreadCount = 0
				}
			}
			self.fetchingAllUnreadCounts = false
			self.updateUnreadCount()
			self.isUnreadCountsInitialized = true
		}
	}
}

// MARK: - Container Overrides

extension Account {

	public func existingFeed(with feedID: String) -> Feed? {
		return idToFeedDictionary[feedID]
	}
}

// MARK: - OPMLRepresentable

extension Account: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {
		var s = ""
		for feed in topLevelFeeds {
			s += feed.OPMLString(indentLevel: indentLevel + 1)
		}
		for folder in folders! {
			s += folder.OPMLString(indentLevel: indentLevel + 1)
		}
		return s
	}
}
