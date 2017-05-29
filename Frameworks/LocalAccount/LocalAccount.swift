//
//  LocalAccount.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/23/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSXML
import RSWeb
import DataModel

private let localAccountType = "OnMyMac"

public final class LocalAccount: Account, PlistProvider  {

	public let identifier: String
	public let type = localAccountType
	public let nameForDisplay = NSLocalizedString("On My Mac", comment: "Local account name")
	
	private let settingsFile: String
	private let dataFolder: String
	private let diskSaver: DiskSaver
	fileprivate let topLevelFolders = NSMutableDictionary()
	fileprivate let topLevelFeeds = NSMutableDictionary()
	fileprivate let localDatabase: LocalDatabase
	private let refresher = LocalAccountRefresher()
	
	public var flattenedFeeds: NSSet {
		get {
			let feeds = NSMutableSet(array: topLevelFeeds.allValues)
			for oneFolder in topLevelFolders.allValues {
				feeds.addObjects(from: (oneFolder as! LocalFolder).flattenedFeeds.allObjects)
			}
			return feeds
		}
	}
	
	public var flattenedFeedIDs: Set<String> {
		get {
			return Set(flattenedFeeds.flatMap { ($0 as? LocalFeed)?.feedID })
		}
	}

	public var account: Account? {
		get {
			return self
		}
	}

	public var unreadCount = 0 {
		didSet {
			postUnreadCountDidChangeNotification()
		}
	}

	public var plist: AnyObject? {
		get {
			return createDiskDictionary()
		}
	}

	public var refreshInProgress: Bool {
		get {
			return !refresher.progress.isComplete
		}
	}
	
	required public init(settingsFile: String, dataFolder: String, identifier: String) {

		self.settingsFile = settingsFile
		self.dataFolder = dataFolder
		self.identifier = identifier

		let databaseFile = (dataFolder as NSString).appendingPathComponent("Articles0.db")
		self.localDatabase = LocalDatabase(databaseFile: databaseFile)
		self.diskSaver = DiskSaver(path: settingsFile)
		
		self.localDatabase.account = self
		self.diskSaver.delegate = self
		self.refresher.account = self

		pullSettingsAndTopLevelItemsFromFile()

		self.localDatabase.startup()

		updateUnreadCountsForTopLevelFolders()
		updateUnreadCount()

		NotificationCenter.default.addObserver(self, selector: #selector(folderChildrenDidChange(_:)), name: NSNotification.Name(rawValue: FolderChildrenDidChangeNotification), object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(articleStatusesDidChange(_:)), name: .ArticleStatusesDidChange, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(refreshProgressDidChange(_:)), name: .DownloadProgressDidChange, object: nil)
		
		DispatchQueue.main.async() { () -> Void in
			self.updateUnreadCounts(feedIDs: self.flattenedFeedIDs)
		}
	}

	public init?(plist: AnyObject) {

		return nil
	}

	// MARK: Account

	public func refreshAll() {

		refresher.refreshFeeds(flattenedFeeds)
	}

	public func markArticles(_ articles: NSSet, statusKey: ArticleStatusKey, flag: Bool) {

		if statusKey == .read {
			for oneArticle in articles {
				if let oneArticle = oneArticle as? LocalArticle, let oneFeed = existingFeedWithID(oneArticle.feedID) as? LocalFeed {
					oneFeed.addToUnreadCount(amount: flag ? -1 : 1)
				}
			}
		}
		
		localDatabase.markArticles(articles, statusKey: statusKey, flag: flag)
		postArticleStatusesDidChangeNotification(articles)
	}

	public func importOPML(_ opmlDocument: Any) {
		
		if let opmlItems = (opmlDocument as? RSOPMLDocument)?.children as? [RSOPMLItem] {
			performDataModelBatchUpdates {
				importOPMLItems(opmlItems)
			}
		}

		refreshAll()
	}
	
	public func fetchArticles(for objects: [AnyObject]) -> [Article] {
		
		var articlesSet = Set<LocalArticle>()
		
		for oneObject in objects {
			
			if let oneFeed = oneObject as? LocalFeed {
				articlesSet.formUnion(fetchArticlesForFeed(oneFeed))
			}
			else if let oneFolder = oneObject as? LocalFolder {
				articlesSet.formUnion(fetchArticlesForFolder(oneFolder))
			}
		}
		
		return Array(articlesSet)
	}

	// MARK: Folder

	public func fetchArticles() -> [Article] {
		
		return [Article]() // Shouldn’t get called.
	}
	
	public func canAddItem(_ item: AnyObject) -> Bool {

		return item is Feed || item is Folder
	}

	public func addItem(_ item: AnyObject) -> Bool {

		if !canAddItem(item) {
			return false
		}
		
		if let feed = item as? LocalFeed {
			return addFeed(feed)
		}

		if let folder = item as? LocalFolder {
			return addFolder(folder)
		}

		return false
	}

	public func canAddFolderWithName(_ folderName: String) -> Bool {
		
		return true
	}

	public func ensureFolderWithName(_ folderName: String) -> Folder? {
		
		if let folder = existingFolderWithName(folderName) {
			return folder
		}
		
		let folder = LocalFolder(nameForDisplay: folderName, account: self)
		if addItem(folder) {
			return folder
		}
		return nil
	}

	public func createFeedWithName(_ name: String?, editedName: String?, urlString: String) -> Feed? {

		let feed = LocalFeed(account: self, url: urlString, feedID: urlString)
		feed.name = name
		feed.editedName = editedName
		return feed
	}

	public func deleteItems(_ items: [AnyObject]) {

		items.forEach { deleteItem($0) }
		FolderPostChildrenDidChangeNotification(self)
	}

	public func existingFeedWithID(_ feedID: String) -> Feed? {
		
		return existingFeedWithURL(feedID)
	}
	
	public func existingFeedWithURL(_ urlString: String) -> Feed? {
		
		if let feed = topLevelFeeds[urlString] as? Feed {
			return feed
		}
		for oneFolder in topLevelFolders.allValues {
			if let oneFolder = oneFolder as? LocalFolder {
				if let feed = oneFolder.existingFeedWithURL(urlString) {
					return feed
				}
			}
		}
		return nil
	}
	
	// MARK: UnreadCountProvider

	public func updateUnreadCount() {

		var updatedUnreadCount = 0
		let _ = visitObjects(false) { (oneChild) -> Bool in

			if let oneUnreadCountProvider = oneChild as? UnreadCountProvider {
				updatedUnreadCount += oneUnreadCountProvider.unreadCount
			}
			return false
		}

		if updatedUnreadCount != unreadCount {
			unreadCount = updatedUnreadCount
		}
	}

	func updateUnreadCountForFeed(_ feed: LocalFeed) {
		
		updateUnreadCounts(feedIDs: [feed.feedID])
	}
	
	public func visitObjects(_ recurse: Bool, visitBlock: FolderVisitBlock) -> Bool {
		
		for oneFeed in topLevelFeeds.allValues {
			if visitBlock(oneFeed as AnyObject) {
				return true
			}
		}
		
		for oneFolder in topLevelFolders.allValues {
			
			if visitBlock(oneFolder as AnyObject) {
				return true
			}
			
			if recurse {
				if let oneFolder = oneFolder as? Folder {
					if oneFolder.visitObjects(recurse, visitBlock: visitBlock) {
						return true
					}
				}
			}
		}

		return false
	}

	// MARK: Notifications

	dynamic func folderChildrenDidChange(_ note: Notification) {

		if let _ = note.object as? LocalAccount {
			diskSaver.dirty = true
		}
		else if let obj = note.object, objectIsDescendant(obj as AnyObject) {
			diskSaver.dirty = true
		}
		updateUnreadCount()
	}
	
	dynamic func articleStatusesDidChange(_ note: Notification) {
		
		guard let articles = note.userInfo?[articlesKey] as? NSSet else {
			return
		}
		
		var feedIDs = Set<String>()
		for oneArticle in articles {
			if let oneLocalArticle = oneArticle as? LocalArticle {
				feedIDs.insert(oneLocalArticle.feedID)
			}
		}
		
		if feedIDs.isEmpty {
			return
		}
		updateUnreadCounts(feedIDs: feedIDs)
		diskSaver.dirty = true
	}
	
	dynamic func unreadCountDidChange(_ notification: Notification) {
		
		guard let obj = notification.object else {
			return
		}
		if obj is LocalFeed || obj is LocalFolder || obj is LocalAccount {
			diskSaver.dirty = true
		}
		updateUnreadCount()
	}

	dynamic func refreshProgressDidChange(_ notification: Notification) {

		guard let progress = notification.object as? DownloadProgress, progress === refresher.progress else {
			return
		}

		NotificationCenter.default.post(name: .AccountRefreshProgressDidChange, object: self, userInfo: [progressKey: progress])
	}

	// MARK: Private

	private func addFeed(_ feed: LocalFeed) -> Bool {

		topLevelFeeds[feed.feedID] = feed
		FolderPostChildrenDidChangeNotification(self)
		return true
	}

	private func addFolder(_ folder: LocalFolder) -> Bool {

		topLevelFolders[folder.folderID] = folder
		FolderPostChildrenDidChangeNotification(self)
		return true
	}

	// MARK: Fetching
	
	func fetchArticlesForFeed(_ feed: LocalFeed) -> Set<LocalArticle> {
		
		return localDatabase.fetchArticlesForFeed(feed)
	}
	
	func fetchArticlesForFolder(_ folder: LocalFolder) -> Set<LocalArticle> {
		
		return localDatabase.fetchUnreadArticlesForFolder(folder)
	}
	
	// MARK: Updating
	
	func update(_ feed: LocalFeed, parsedFeed: RSParsedFeed, completionHandler: @escaping RSVoidCompletionBlock) {
		
		if let titleFromFeed = parsedFeed.title {
			if feed.name != titleFromFeed {
				feed.name = titleFromFeed
				self.diskSaver.dirty = true
			}
		}
		if let linkFromFeed = parsedFeed.link {
			if feed.homePageURL != linkFromFeed {
				feed.homePageURL = linkFromFeed
				self.diskSaver.dirty = true
			}
		}
		
		localDatabase.updateFeedWithParsedFeed(feed, parsedFeed: parsedFeed) {
			
			feed.updateUnreadCount()
			completionHandler()
		}
	}
	
	// MARK: Writing to Disk

	private func createDiskDictionary() -> NSDictionary {

		let d = NSMutableDictionary()

		let diskChildren = NSMutableArray()
		topLevelFolders.allValues.forEach { (oneFolder) in
			if let oneFolder = oneFolder as? PlistProvider, let onePlist = oneFolder.plist {
				diskChildren.add(onePlist)
			}
		}
		topLevelFeeds.allValues.forEach { (oneFeed) in
			if let oneFeed = oneFeed as? PlistProvider, let onePlist = oneFeed.plist {
				diskChildren.add(onePlist)
			}
		}
		d.setObject(diskChildren as NSArray, forKey: diskDictionaryChildrenKey as NSString)

		return d
	}

	// MARK: Reading from Disk

	private func pullSettingsAndTopLevelItemsFromFile() {

		guard let d = NSDictionary(contentsOfFile: settingsFile) else {
			return
		}

		performDataModelBatchUpdates {
			
			if let children = d[diskDictionaryChildrenKey] as? NSArray {
				pullTopLevelItemsFromArray(children)
			}
		}
	}
	
	func objectWithDiskDictionary(_ d: NSDictionary) -> AnyObject? {

		if let _ = d[feedURLKey] {
			return LocalFeed(account: self, diskDictionary: d)
		}

		if let _ = d[folderIDKey] {
			return LocalFolder(account: self, diskDictionary: d)
		}

		return nil
	}

	func childrenForDiskArray(_ children: NSArray) -> [Any] {

		var items = [Any]()

		children.forEach { (oneChild) in

			guard let oneDictionary = oneChild as? NSDictionary else {
				return
			}

			if let oneObject = objectWithDiskDictionary(oneDictionary) {
				items.append(oneObject)
			}
		}

		return items
	}

	private func pullTopLevelItemsFromArray(_ children: NSArray) {

		let items = childrenForDiskArray(children)
		
		items.forEach { (oneItem) in
			
			if let oneFolder = oneItem as? LocalFolder {
				topLevelFolders[oneFolder.folderID] = oneFolder
			}
			else if let oneFeed = oneItem as? LocalFeed {
				topLevelFeeds[oneFeed.feedID] = oneFeed
			}
		}
	}
	
	// MARK: OPML Export
	
	public func opmlString(indentLevel: Int) -> String {
		
		var s = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
		s += "<opml version=\"1.1\">\n"
		s += "<head>\n"
		s += "\t<title>mySubscriptions</title>\n"
		s += "\t</head>\n"
		s += "\t<body>\n"

		let indentLevel = 1
		
		let _ = visitChildren { (oneChild) -> Bool in
			if let oneFolder = oneChild as? LocalFolder {
				s += oneFolder.opmlString(indentLevel: indentLevel)
			}
			else if let oneFeed = oneChild as? LocalFeed {
				s += oneFeed.opmlString(indentLevel: indentLevel)
			}
			
			return false
		}
		
		s += "\t</body>\n"
		s += "</opml>\n"
		
		return s
	}
}

private extension LocalAccount {

	// MARK: Deleting

	func deleteItem(_ item: AnyObject) {

		if let feed = item as? LocalFeed {
			deleteFeed(feed)
		}
		else if let folder = item as? LocalFolder {
			deleteFolder(folder)
		}
	}

	func deleteFeed(_ feed: LocalFeed) {

		topLevelFeeds[feed.feedID] = nil
	}

	func deleteFolder(_ folder: LocalFolder) {

		topLevelFolders[folder.folderID] = nil
	}
	
	// MARK: Unread Counts
	
	func updateUnreadCountsForFeeds(_ feeds: Set<LocalFeed>) {
		
		let feedIDs = feeds.map { $0.feedID }
		updateUnreadCounts(feedIDs: Set(feedIDs))
	}
	
	func updateUnreadCountsForTopLevelFolders() {
		
		topLevelFolders.allValues.forEach { (oneFolder) in
			if let oneFolder = oneFolder as? UnreadCountProvider {
				oneFolder.updateUnreadCount()
			}
		}
	}
	
	// MARK: OPML Import

	func importOPMLItems(_ items: [RSOPMLItem]) {

		// FeedBin’s OPML duplicates everything in a folder onto the top level.
		// So: do the folders first, then the top level feeds.

		importOPMLTopLevelFolders(items)
		importOPMLTopLevelFeeds(items)
	}

	func importOPMLTopLevelFolders(_ items: [RSOPMLItem]) {

		for oneItem in items {

			if oneItem.isFolder, let childItems = oneItem.children as? [RSOPMLItem] {
				importOPMLTopLevelFolder(oneItem, childItems)
			}
		}
	}

	func importOPMLTopLevelFeeds(_ items: [RSOPMLItem]) {

		for oneItem in items {

			if !oneItem.isFolder {
				importOPMLFeedIntoFolder(oneItem, nil)
			}
		}
	}

	func importOPMLTopLevelFolder(_ opmlFolder: RSOPMLItem, _ items: [RSOPMLItem]) {

		let folderTitle = opmlFolder.titleFromAttributes ?? "Untitled"
		let folder = ensureFolderWithName(folderTitle)! as! LocalFolder
		importOPMLItemsIntoFolder(items, folder)
		let _ = addItem(folder)
	}

	func importOPMLItemsIntoFolder(_ items: [RSOPMLItem], _ folder: LocalFolder) {

		// nil folder for top level.

		for oneItem in items {

			if oneItem.isFolder, let childItems = oneItem.children as? [RSOPMLItem] {
				importOPMLItemsIntoFolder(childItems, folder)
				continue
			}

			else {
				importOPMLFeedIntoFolder(oneItem, folder)
			}
		}
	}

	func importOPMLFeedIntoFolder(_ opmlFeed: RSOPMLItem, _ folder: LocalFolder?) {

		guard let feedSpecifier = opmlFeed.opmlFeedSpecifier, let feedURL = feedSpecifier.feedURL else {
			return
		}

		if let _ = existingFeedWithURL(feedURL) {
			return
		}

		let feed = LocalFeed(account: self, url: feedURL, feedID: feedURL)
		if let name = feedSpecifier.title {
			feed.editedName = name
		}
		if let folder = folder {
			let _ = folder.addItem(feed)
		}
		else {
			let _ = addItem(feed)
		}
	}
	
	// MARK: Unread Counts
	
	func updateUnreadCountsWithDatabaseDictionary(_ unreadCountsDictionary: [String: Int]) {
		
		for oneFeed in flattenedFeeds {
			
			guard let oneFeed = oneFeed as? LocalFeed, let unreadCount = unreadCountsDictionary[oneFeed.feedID] else {
				continue
			}
			
			if oneFeed.unreadCount != unreadCount {
				oneFeed.unreadCount = unreadCount
			}
		}
		
		updateUnreadCountsForTopLevelFolders()
	}
	
	func updateUnreadCounts(feedIDs: Set<String>) {
		
		self.localDatabase.updateUnreadCounts(for: Set(feedIDs), completion: { (unreadCounts) in
			
			self.updateUnreadCountsWithDatabaseDictionary(unreadCounts)
		})
	}
}

