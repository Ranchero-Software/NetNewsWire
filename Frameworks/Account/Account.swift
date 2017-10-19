//
//  Account.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Data
import RSParser
import Database
import RSWeb

public extension Notification.Name {

	public static let AccountRefreshDidBegin = Notification.Name(rawValue: "AccountRefreshDidBegin")
	public static let AccountRefreshDidFinish = Notification.Name(rawValue: "AccountRefreshDidFinish")
	public static let AccountRefreshProgressDidChange = Notification.Name(rawValue: "AccountRefreshProgressDidChange")
	public static let AccountDidDownloadArticles = Notification.Name(rawValue: "AccountDidDownloadArticles")
	
	public static let StatusesDidChange = Notification.Name(rawValue: "StatusesDidChange")
}

public enum AccountType: Int {

	// Raw values should not change since they’re stored on disk.
	case onMyMac = 1
	case feedly = 16
	case feedbin = 17
	case feedWrangler = 18
	case newsBlur = 19
	// TODO: more
}

public final class Account: DisplayNameProvider, UnreadCountProvider, Container, Hashable {

	public struct UserInfoKey {
		public static let newArticles = "newArticles" // AccountDidDownloadArticles
		public static let updatedArticles = "updatedArticles" // AccountDidDownloadArticles
		public static let statuses = "statuses" // StatusesDidChange
		public static let articles = "articles" // StatusesDidChange
		public static let feeds = "feeds" // StatusesDidChange
	}

	public let accountID: String
	public let type: AccountType
	public var nameForDisplay = ""
	public let hashValue: Int
	public var children = [AnyObject]()
	let settingsFile: String
	let dataFolder: String
	let database: Database
	let delegate: AccountDelegate
	var username: String?
	var saveTimer: Timer?

	public var dirty = false {
		didSet {

			if refreshInProgress {
				if let _ = saveTimer {
					removeSaveTimer()
				}
				return
			}

			if dirty {
				resetSaveTimer()
			}
			else {
				removeSaveTimer()
			}
		}
	}

    public var unreadCount = 0 {
        didSet {
            if unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
            }
        }
    }
    
	var refreshInProgress = false {
		didSet {
			if refreshInProgress != oldValue {
				if refreshInProgress {
					NotificationCenter.default.post(name: .AccountRefreshDidBegin, object: self)
				}
				else {
					NotificationCenter.default.post(name: .AccountRefreshDidFinish, object: self)
					if dirty {
						resetSaveTimer()
					}
				}
			}
		}
	}

	var refreshProgress: DownloadProgress {
		get {
			return delegate.refreshProgress
		}
	}

	var supportsSubFolders: Bool {
		get {
			return delegate.supportsSubFolders
		}
	}

	init?(dataFolder: String, settingsFile: String, type: AccountType, accountID: String) {

		// TODO: support various syncing systems.
		precondition(type == .onMyMac)
		self.delegate = LocalAccountDelegate()

		self.accountID = accountID
		self.type = type
		self.settingsFile = settingsFile
		self.dataFolder = dataFolder
		self.hashValue = accountID.hashValue
		
		let databaseFilePath = (dataFolder as NSString).appendingPathComponent("DB.sqlite3")
		self.database = Database(databaseFilePath: databaseFilePath, accountID: accountID)

		NotificationCenter.default.addObserver(self, selector: #selector(downloadProgressDidChange(_:)), name: .DownloadProgressDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		
		pullObjectsFromDisk()
		
		DispatchQueue.main.async {
			self.updateUnreadCount()
		}
	}
	
	// MARK: - API

	public func refreshAll() {

		delegate.refreshAll(for: self)
	}

	func update(_ feed: Feed, with parsedFeed: ParsedFeed, _ completion: @escaping RSVoidCompletionBlock) {

		database.update(feed: feed, parsedFeed: parsedFeed) { (newArticles, updatedArticles) in

			var userInfo = [String: Any]()
			if let newArticles = newArticles, !newArticles.isEmpty {
				self.updateUnreadCounts(for: Set([feed]))
				userInfo[UserInfoKey.newArticles] = newArticles
			}
			if let updatedArticles = updatedArticles, !updatedArticles.isEmpty {
				userInfo[UserInfoKey.updatedArticles] = updatedArticles
			}

			completion()

			NotificationCenter.default.post(name: .AccountDidDownloadArticles, object: self, userInfo: userInfo.isEmpty ? nil : userInfo)
		}
	}

	public func markArticles(_ articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) {
	
		guard let updatedStatuses = database.mark(articles, statusKey: statusKey, flag: flag) else {
			return
		}
		
		let updatedArticleIDs = updatedStatuses.articleIDs()
		let updatedArticles = Set(articles.filter{ updatedArticleIDs.contains($0.articleID) })
        
        noteStatusesForArticlesDidChange(updatedArticles)
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
		children += [folder]
		dirty = true

		return folder
	}

	public func canAddFeed(_ feed: Feed, to folder: Folder?) -> Bool {

		// If folder is nil, then it should go at the top level.
		// The same feed in multiple folders is allowed.
		// But the same feed can’t appear twice in the same folder
		// (or at the top level).

		return true // TODO
	}

	public func addFeed(_ feed: Feed, to folder: Folder?) -> Bool {

		// Return false if it couldn’t be added.
		// If it already existed in that folder, return true.

		var didAddFeed = false
		let uniquedFeed = existingFeed(with: feed.feedID) ?? feed
		
		if let folder = folder {
			didAddFeed = folder.addFeed(uniquedFeed)
		}
		else {
			if !topLevelObjectsContainsFeed(uniquedFeed) {
				children += [uniquedFeed]
			}
			didAddFeed = true
		}
		
		return didAddFeed // TODO
	}

	public func createFeed(with name: String?, editedName: String?, url: String) -> Feed? {
		
		// For syncing, this may need to be an async method with a callback,
		// since it will likely need to call the server.
		
		if let feed = existingFeed(withURL: url) {
			if let editedName = editedName {
				feed.editedName = editedName
			}
			return feed
		}
		
		let feed = Feed(accountID: accountID, url: url, feedID: url)
		feed.name = name
		feed.editedName = editedName
		return feed
	}
	
	public func canAddFolder(_ folder: Folder, to containingFolder: Folder?) -> Bool {

		return false // TODO
	}

	public func addFolder(_ folder: Folder, to containingFolder: Folder?) -> Bool {

		return false // TODO
	}

	public func importOPML(_ opmlDocument: RSOPMLDocument) {

		guard let children = opmlDocument.children else {
			return
		}
		importOPMLItems(children, parentFolder: nil, foldersAllowed: true)
		dirty = true
	}

	public func updateUnreadCounts(for feeds: Set<Feed>) {

		if feeds.isEmpty {
			return
		}
		
		database.fetchUnreadCounts(for: feeds) { (unreadCountDictionary) in

			for feed in feeds {
				if let unreadCount = unreadCountDictionary[feed] {
					feed.unreadCount = unreadCount
				}
			}
		}
	}

	public func fetchArticles(for feed: Feed) -> Set<Article> {
		
		return database.fetchArticles(for: feed)
	}
	
	public func fetchArticles(folder: Folder) -> Set<Article> {
		
		return database.fetchUnreadArticles(for: folder.flattenedFeeds())
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

		// Update the unread count if it’s a direct child.
		// If the object is owned by this account, then mark dirty —
		// since unread counts are saved to disk along with other feed info.

		if let object = note.object {

			if objectIsChild(object as AnyObject) {
				updateUnreadCount()
				self.dirty = true
				return
			}

			if let feed = object as? Feed {
				if feed.account === self {
					self.dirty = true
				}
			}
			if let folder = object as? Folder {
				if folder.account === self {
					self.dirty = true
				}
			}
		}
	}

	// MARK: - Equatable

	public class func ==(lhs: Account, rhs: Account) -> Bool {

		return lhs === rhs
	}
}


// MARK: - Disk (Public)

extension Account {

	func objects(with diskObjects: [[String: Any]]) -> [AnyObject] {

		return diskObjects.flatMap { object(with: $0) }
	}
}

// MARK: - Disk (Private)

private extension Account {
	
	struct Key {
		static let children = "children"
		static let userInfo = "userInfo"
		static let unreadCount = "unreadCount"
	}

	func object(with diskObject: [String: Any]) -> AnyObject? {

		if Feed.isFeedDictionary(diskObject) {
			return Feed(accountID: accountID, dictionary: diskObject)
		}
		return Folder(account: self, dictionary: diskObject)
	}

	func pullObjectsFromDisk() {

		let settingsFileURL = URL(fileURLWithPath: settingsFile)
		guard let d = NSDictionary(contentsOf: settingsFileURL) as? [String: Any] else {
			return
		}
		guard let childrenArray = d[Key.children] as? [[String: Any]] else {
			return
		}
		children = objects(with: childrenArray)

		if let savedUnreadCount = d[Key.unreadCount] as? Int {
			DispatchQueue.main.async {
				self.unreadCount = savedUnreadCount
			}
		}

		let userInfo = d[Key.userInfo] as? NSDictionary
		delegate.update(account: self, withUserInfo: userInfo)
	}

	func diskDictionary() -> NSDictionary {

		let diskObjects = children.flatMap { (object) -> [String: Any]? in

			if let folder = object as? Folder {
				return folder.dictionary
			}
			else if let feed = object as? Feed {
				return feed.dictionary
			}
			return nil
		}

		var d = [String: Any]()
		d[Key.children] = diskObjects as NSArray
		d[Key.unreadCount] = unreadCount

		if let userInfo = delegate.userInfo(for: self) {
			d[Key.userInfo] = userInfo
		}

		return d as NSDictionary
	}

	func saveToDiskIfNeeded() {

		if !dirty {
			return
		}

		if refreshInProgress {
			resetSaveTimer()
			return
		}

		saveToDisk()
		dirty = false
	}

	func saveToDisk() {

		let d = diskDictionary()
		do {
			try RSPlist.write(d, filePath: settingsFile)
		}
		catch let error as NSError {
			NSApplication.shared.presentError(error)
		}
	}

	func resetSaveTimer() {

		saveTimer?.rs_invalidateIfValid()

		saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { (timer) in
			self.saveToDiskIfNeeded()
		}
	}

	func removeSaveTimer() {

		saveTimer?.rs_invalidateIfValid()
		saveTimer = nil
	}
}

// MARK: - Private

private extension Account {

	func topLevelObjectsContainsFeed(_ feed: Feed) -> Bool {
		
		return children.contains(where: { (object) -> Bool in
			if let oneFeed = object as? Feed {
				if oneFeed.feedID == feed.feedID {
					return true
				}
			}
			return false
		})
	}

	func importOPMLItems(_ items: [RSOPMLItem], parentFolder: Folder?, foldersAllowed: Bool) {

		for item in items {

			if let feedSpecifier = item.feedSpecifier {
				if hasFeed(withURL: feedSpecifier.feedURL) {
					continue
				}

			}

			if item.isFolder {

			}
			else {

			}
		}
	}
    
    func updateUnreadCount() {
        
        unreadCount = calculateUnreadCount(children)
    }
    
    func noteStatusesForArticlesDidChange(_ articles: Set<Article>) {
        
		let feeds = Set(articles.flatMap { $0.feed })
		let statuses = Set(articles.map { $0.status })
        
        // .UnreadCountDidChange notification will get sent to Folder and Account objects,
        // which will update their own unread counts.
        updateUnreadCounts(for: feeds)
        
        NotificationCenter.default.post(name: .StatusesDidChange, object: self, userInfo: [UserInfoKey.statuses: statuses, UserInfoKey.articles: articles, UserInfoKey.feeds: feeds])
    }
}

// MARK: - OPMLRepresentable

extension Account: OPMLRepresentable {

	public func OPMLString(indentLevel: Int) -> String {

		var s = ""
		for oneObject in children {
			if let oneOPMLObject = oneObject as? OPMLRepresentable {
				s += oneOPMLObject.OPMLString(indentLevel: indentLevel + 1)
			}
		}
		return s
	}
}
