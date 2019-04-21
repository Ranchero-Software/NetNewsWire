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
	static let ShowFeedNamesDidChange = Notification.Name(rawValue: "ShowFeedNamesDidChange")
	static let ArticlesReinitialized = Notification.Name(rawValue: "ArticlesReinitialized")
	static let ArticleDataDidChange = Notification.Name(rawValue: "ArticleDataDidChange")
	static let ArticlesDidChange = Notification.Name(rawValue: "ArticlesDidChange")
}

class NavigationModelController {

	static let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)
	
	var expandedNodes = [Node]()
	var shadowTable = [[Node]]()
	
	let treeControllerDelegate = FeedTreeControllerDelegate()
	lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	
	private var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortDirectionDidChange()
			}
		}
	}
	
	var showFeedNames = false {
		didSet {
			NotificationCenter.default.post(name: .ShowFeedNamesDidChange, object: self, userInfo: nil)
		}
	}
	var showAvatars = false
	
	var timelineFetcher: ArticleFetcher? {
		didSet {
			if timelineFetcher is Feed {
				showFeedNames = false
			} else {
				showFeedNames = true
			}
			fetchArticles()
			NotificationCenter.default.post(name: .ArticlesReinitialized, object: self, userInfo: nil)
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
	
	private var articleRowMap = [String: Int]() // articleID: rowIndex

	init() {

		for section in treeController.rootNode.childNodes {
			expandedNodes.append(section)
			shadowTable.append([Node]())
		}
		
		rebuildShadowTable()
		
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		
	}
	
	// MARK: Notifications
	
	@objc func userDefaultsDidChange(_ note: Notification) {
		self.sortDirection = AppDefaults.timelineSortDirection
	}
	
	@objc func accountDidDownloadArticles(_ note: Notification) {
		
		guard let feeds = note.userInfo?[Account.UserInfoKey.feeds] as? Set<Feed> else {
			return
		}
		
		let shouldFetchAndMergeArticles = representedObjectsContainsAnyFeed(feeds) || representedObjectsContainsAnyPseudoFeed()
		if shouldFetchAndMergeArticles {
			queueFetchAndMergeArticles()
		}
		
	}

	// MARK: API

	func rebuildShadowTable() {
		
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
			
			shadowTable[i] = result
			
		}
		
	}

	func nodeFor(_ indexPath: IndexPath) -> Node? {
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
	
}

private extension NavigationModelController {

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
		NavigationModelController.fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticles))
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
	
	func representedObjectsContainsAnyPseudoFeed() -> Bool {
		if timelineFetcher is PseudoFeed {
			return true
		}
		return false
	}
	
	func representedObjectsContainsAnyFeed(_ feeds: Set<Feed>) -> Bool {
		
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

	// MARK: Misc
	
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
	
}
