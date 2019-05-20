//
//  NavigationModelController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles
import RSCore
import RSTree

public extension Notification.Name {
	static let MasterSelectionDidChange = Notification.Name(rawValue: "MasterSelectionDidChange")
	static let BackingStoresDidRebuild = Notification.Name(rawValue: "BackingStoresDidRebuild")
	static let ArticlesReinitialized = Notification.Name(rawValue: "ArticlesReinitialized")
	static let ArticleDataDidChange = Notification.Name(rawValue: "ArticleDataDidChange")
	static let ArticlesDidChange = Notification.Name(rawValue: "ArticlesDidChange")
	static let ArticleSelectionDidChange = Notification.Name(rawValue: "ArticleSelectionDidChange")
}

class NavigationStateController {

	static let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
	
	private var articleRowMap = [String: Int]() // articleID: rowIndex
	
	private var animatingChanges = false
	private var expandedNodes = [Node]()
	private var shadowTable = [[Node]]()
	
	private var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortDirectionDidChange()
			}
		}
	}

	private let treeControllerDelegate = FeedTreeControllerDelegate()
	lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	
	var rootNode: Node {
		return treeController.rootNode
	}
	
	var numberOfSections: Int {
		return shadowTable.count
	}

	var currentMasterIndexPath: IndexPath? {
		didSet {
			guard let ip = currentMasterIndexPath, let node = nodeFor(ip) else {
				assertionFailure()
				return
			}
			if let fetcher = node.representedObject as? ArticleFetcher {
				timelineFetcher = fetcher
			}
			NotificationCenter.default.post(name: .MasterSelectionDidChange, object: self, userInfo: nil)
		}
	}
	
	var timelineName: String? {
		return (timelineFetcher as? DisplayNameProvider)?.nameForDisplay
	}
	
	var timelineFetcher: ArticleFetcher? {
		didSet {
			currentArticleIndexPath = nil
			if timelineFetcher is Feed {
				showFeedNames = false
			} else {
				showFeedNames = true
			}
			fetchArticles()
			NotificationCenter.default.post(name: .ArticlesReinitialized, object: self, userInfo: nil)
		}
	}
	
	
	var showFeedNames = false
	var showAvatars = false

	var isPrevArticleAvailable: Bool {
		guard let indexPath = currentArticleIndexPath else {
			return false
		}
		return indexPath.row > 0
	}
	
	var isNextArticleAvailable: Bool {
		guard let indexPath = currentArticleIndexPath else {
			return false
		}
		return indexPath.row + 1 < articles.count
	}
	
	var prevArticleIndexPath: IndexPath? {
		guard let indexPath = currentArticleIndexPath else {
			return nil
		}
		return IndexPath(row: indexPath.row - 1, section: indexPath.section)
	}
	
	var nextArticleIndexPath: IndexPath? {
		guard let indexPath = currentArticleIndexPath else {
			return nil
		}
		return IndexPath(row: indexPath.row + 1, section: indexPath.section)
	}
	
	var firstUnreadArticleIndexPath: IndexPath? {
		for (row, article) in articles.enumerated() {
			if !article.status.read {
				return IndexPath(row: row, section: 0)
			}
		}
		return nil
	}
	
	var currentArticle: Article? {
		if let indexPath = currentArticleIndexPath {
			return articles[indexPath.row]
		}
		return nil
	}
	
	var currentArticleIndexPath: IndexPath? {
		didSet {
			if currentArticleIndexPath != oldValue {
				NotificationCenter.default.post(name: .ArticleSelectionDidChange, object: self, userInfo: nil)
			}
		}
	}
	
	var articles = ArticleArray() {
		didSet {
			if articles == oldValue {
				return
			}
			if articles.representSameArticlesInSameOrder(as: oldValue) {
				articleRowMap = [String: Int]()
				NotificationCenter.default.post(name: .ArticleDataDidChange, object: self, userInfo: nil)
				return
			}
			updateShowAvatars()
			articleRowMap = [String: Int]()
			NotificationCenter.default.post(name: .ArticlesDidChange, object: self, userInfo: nil)
		}
	}
	
	var isTimelineUnreadAvailable: Bool {
		if let unreadProvider = timelineFetcher as? UnreadCountProvider {
			return unreadProvider.unreadCount > 0
		}
		return false
	}
	
	var isAnyUnreadAvailable: Bool {
		return appDelegate.unreadCount > 0
	}
	
	init() {

		for section in treeController.rootNode.childNodes {
			expandedNodes.append(section)
			shadowTable.append([Node]())
		}
		
		rebuildShadowTable()
		
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .AccountsDidChange, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		
	}
	
	// MARK: Notifications
	
	@objc func containerChildrenDidChange(_ note: Notification) {
		rebuildBackingStores()
	}
	
	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildBackingStores()
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		rebuildBackingStores()
	}

	@objc func accountStateDidChange(_ note: Notification) {
		rebuildBackingStores()
	}
	
	@objc func accountsDidChange(_ note: Notification) {
		rebuildBackingStores()
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		self.sortDirection = AppDefaults.timelineSortDirection
	}
	
	@objc func accountDidDownloadArticles(_ note: Notification) {
		
		guard let feeds = note.userInfo?[Account.UserInfoKey.feeds] as? Set<Feed> else {
			return
		}
		
		let shouldFetchAndMergeArticles = timelineFetcherContainsAnyFeed(feeds) || timelineFetcherContainsAnyPseudoFeed()
		if shouldFetchAndMergeArticles {
			queueFetchAndMergeArticles()
		}
		
	}

	// MARK: API
	
	func beginUpdates() {
		animatingChanges = true
	}

	func endUpdates() {
		animatingChanges = false
	}
	
	func rowsInSection(_ section: Int) -> Int {
		return shadowTable[section].count
	}
	
	func rebuildShadowTable() {
		
		shadowTable = [[Node]]()

		for i in 0..<treeController.rootNode.numberOfChildNodes {
			
			var result = [Node]()
			
			if let nodes = treeController.rootNode.childAtIndex(i)?.childNodes {
				for node in nodes {
					result.append(node)
					if expandedNodes.contains(node) {
						for child in node.childNodes {
							result.append(child)
						}
					}
				}
			}
			
			shadowTable.append(result)
			
		}
		
	}

	func isExpanded(_ node: Node) -> Bool {
		return expandedNodes.contains(node)
	}
	
	func nodeFor(_ indexPath: IndexPath) -> Node? {
		guard indexPath.section < shadowTable.count || indexPath.row < shadowTable[indexPath.section].count else {
			return nil
		}
		return shadowTable[indexPath.section][indexPath.row]
	}
	
	func indexPathFor(_ node: Node) -> IndexPath? {
		for i in 0..<shadowTable.count {
			if let row = shadowTable[i].firstIndex(of: node) {
				return IndexPath(row: row, section: i)
			}
		}
		return nil
	}
	
	func expand(section: Int, completion: ([IndexPath]) -> ()) {
		
		guard let expandNode = treeController.rootNode.childAtIndex(section) else {
			return
		}
		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		var indexPathsToInsert = [IndexPath]()
		var i = 0
		
		func addNode(_ node: Node) {
			indexPathsToInsert.append(IndexPath(row: i, section: section))
			shadowTable[section].insert(node, at: i)
			i = i + 1
		}
		
		for child in expandNode.childNodes {
			addNode(child)
			if expandedNodes.contains(child) {
				for gChild in child.childNodes {
					addNode(gChild)
				}
			}
		}
		
		completion(indexPathsToInsert)
		
		animatingChanges = false
		
	}
	
	func expand(_ indexPath: IndexPath, completion: ([IndexPath]) -> ()) {
		
		let expandNode = shadowTable[indexPath.section][indexPath.row]
		expandedNodes.append(expandNode)
		
		animatingChanges = true
		
		var indexPathsToInsert = [IndexPath]()
		for i in 0..<expandNode.childNodes.count {
			if let child = expandNode.childAtIndex(i) {
				let nextIndex = indexPath.row + i + 1
				indexPathsToInsert.append(IndexPath(row: nextIndex, section: indexPath.section))
				shadowTable[indexPath.section].insert(child, at: nextIndex)
			}
		}
		
		completion(indexPathsToInsert)
		
		animatingChanges = false
		
	}
	
	func collapse(section: Int, completion: ([IndexPath]) -> ()) {
		
		animatingChanges = true
		
		guard let collapseNode = treeController.rootNode.childAtIndex(section) else {
			return
		}
		
		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}
		
		var indexPathsToRemove = [IndexPath]()
		for i in 0..<shadowTable[section].count {
			indexPathsToRemove.append(IndexPath(row: i, section: section))
		}
		shadowTable[section] = [Node]()
		
		completion(indexPathsToRemove)
		
		animatingChanges = false
		
	}
	
	func collapse(_ indexPath: IndexPath, completion: ([IndexPath]) -> ()) {
		
		animatingChanges = true
		
		let collapseNode = shadowTable[indexPath.section][indexPath.row]
		if let removeNode = expandedNodes.firstIndex(of: collapseNode) {
			expandedNodes.remove(at: removeNode)
		}
		
		var indexPathsToRemove = [IndexPath]()
		
		for child in collapseNode.childNodes {
			if let index = shadowTable[indexPath.section].firstIndex(of: child) {
				indexPathsToRemove.append(IndexPath(row: index, section: indexPath.section))
			}
		}
		
		for child in collapseNode.childNodes {
			if let index = shadowTable[indexPath.section].firstIndex(of: child) {
				shadowTable[indexPath.section].remove(at: index)
			}
		}
		
		completion(indexPathsToRemove)
		
		animatingChanges = false
		
	}
	
	func indexesForArticleIDs(_ articleIDs: Set<String>) -> IndexSet {
		
		var indexes = IndexSet()
		
		articleIDs.forEach { (articleID) in
			guard let oneIndex = row(for: articleID) else {
				return
			}
			if oneIndex != NSNotFound {
				indexes.insert(oneIndex)
			}
		}
		
		return indexes
	}
	
	func selectNextUnread() {
		
		// This should never happen, but I don't want to risk throwing us
		// into an infinate loop searching for an unread that isn't there.
		if appDelegate.unreadCount < 1 {
			return
		}
		
		if selectNextUnreadArticleInTimeline() {
			return
		}
		
		selectNextUnreadFeedFetcher()
		selectNextUnreadArticleInTimeline()
		
	}
	
}
	
private extension NavigationStateController {

	func rebuildBackingStores() {
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			rebuildShadowTable()
			NotificationCenter.default.post(name: .BackingStoresDidRebuild, object: self, userInfo: nil)
		}
	}
	
	func updateShowAvatars() {
		
		if showFeedNames {
			self.showAvatars = true
			return
		}
		
		for article in articles {
			if let authors = article.authors {
				for author in authors {
					if author.avatarURL != nil {
						self.showAvatars = true
						return
					}
				}
			}
		}
		
		self.showAvatars = false
	}
	
	// MARK: Select Next Unread

	@discardableResult
	func selectNextUnreadArticleInTimeline() -> Bool {
		
		let startingRow: Int = {
			if let indexPath = currentArticleIndexPath {
				return indexPath.row
			} else {
				return 0
			}
		}()
		
		for i in startingRow..<articles.count {
			let article = articles[i]
			if !article.status.read {
				currentArticleIndexPath = IndexPath(row: i, section: 0)
				return true
			}
		}
		
		return false
		
	}
	
	func selectNextUnreadFeedFetcher() {
		
		guard let indexPath = currentMasterIndexPath else {
			assertionFailure()
			return
		}
		
		// Increment or wrap around the IndexPath
		let nextIndexPath: IndexPath = {
			if indexPath.row + 1 >= shadowTable[indexPath.section].count {
				if indexPath.section + 1 >= shadowTable.count {
					return IndexPath(row: 0, section: 0)
				} else {
					return IndexPath(row: 0, section: indexPath.section + 1)
				}
			} else {
				return IndexPath(row: indexPath.row + 1, section: indexPath.section)
			}
		}()
		
		if selectNextUnreadFeedFetcher(startingWith: nextIndexPath) {
			return
		}
		selectNextUnreadFeedFetcher(startingWith: IndexPath(row: 0, section: 0))
		
	}
	
	@discardableResult
	func selectNextUnreadFeedFetcher(startingWith indexPath: IndexPath) -> Bool {
		
		for i in indexPath.section..<shadowTable.count {
			
			for j in indexPath.row..<shadowTable[indexPath.section].count {
				
				let nextIndexPath = IndexPath(row: j, section: i)
				guard let node = nodeFor(nextIndexPath), let unreadCountProvider = node.representedObject as? UnreadCountProvider else {
					assertionFailure()
					return true
				}
				
				if expandedNodes.contains(node) {
					continue
				}
				
				if unreadCountProvider.unreadCount > 0 {
					currentMasterIndexPath = nextIndexPath
					return true
				}
				
			}
			
		}
		
		return false
		
	}
	
	// MARK: Fetching Articles
	
	func fetchArticles() {
		
		guard let timelineFetcher = timelineFetcher else {
			articles = ArticleArray()
			return
		}
		
		let fetchedArticles = timelineFetcher.fetchArticles()
		updateArticles(with: fetchedArticles)
		
	}
	
	func emptyTheTimeline() {
		if !articles.isEmpty {
			articles = [Article]()
		}
	}
	
	func sortDirectionDidChange() {
		updateArticles(with: Set(articles))
	}
	
	func updateArticles(with unsortedArticles: Set<Article>) {
		let sortedArticles = Array(unsortedArticles).sortedByDate(sortDirection)
		if articles != sortedArticles {
			articles = sortedArticles
		}
	}
	
	func row(for articleID: String) -> Int? {
		updateArticleRowMapIfNeeded()
		return articleRowMap[articleID]
	}
	
	func updateArticleRowMap() {
		var rowMap = [String: Int]()
		var index = 0
		articles.forEach { (article) in
			rowMap[article.articleID] = index
			index += 1
		}
		articleRowMap = rowMap
	}
	
	func updateArticleRowMapIfNeeded() {
		if articleRowMap.isEmpty {
			updateArticleRowMap()
		}
	}
	
	func queueFetchAndMergeArticles() {
		NavigationStateController.fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticles))
	}
	
	@objc func fetchAndMergeArticles() {
		
		guard let timelineFetcher = timelineFetcher else {
			return
		}
		
		var unsortedArticles = timelineFetcher.fetchArticles()
		
		// Merge articles by articleID. For any unique articleID in current articles, add to unsortedArticles.
		let unsortedArticleIDs = unsortedArticles.articleIDs()
		for article in articles {
			if !unsortedArticleIDs.contains(article.articleID) {
				unsortedArticles.insert(article)
			}
		}
		
		updateArticles(with: unsortedArticles)
		
	}
	
	func timelineFetcherContainsAnyPseudoFeed() -> Bool {
		if timelineFetcher is PseudoFeed {
			return true
		}
		return false
	}
	
	func timelineFetcherContainsAnyFeed(_ feeds: Set<Feed>) -> Bool {
		
		// Return true if there’s a match or if a folder contains (recursively) one of feeds
		
		if let feed = timelineFetcher as? Feed {
			for oneFeed in feeds {
				if feed.feedID == oneFeed.feedID || feed.url == oneFeed.url {
					return true
				}
			}
		} else if let folder = timelineFetcher as? Folder {
			for oneFeed in feeds {
				if folder.hasFeed(with: oneFeed.feedID) || folder.hasFeed(withURL: oneFeed.url) {
					return true
				}
			}
		}
		
		return false
		
	}
	
}
