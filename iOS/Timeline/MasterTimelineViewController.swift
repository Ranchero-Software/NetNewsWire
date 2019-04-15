//
//  MasterTimelineViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account
import Articles

class MasterTimelineViewController: UITableViewController {

	private var showAvatars = false
	private var rowHeightWithFeedName: CGFloat = 0.0
	private var rowHeightWithoutFeedName: CGFloat = 0.0
	
	private var currentRowHeight: CGFloat {
		return showFeedNames ? rowHeightWithFeedName : rowHeightWithoutFeedName
	}

	static let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)

	var detailViewController: DetailViewController? {
		if let split = splitViewController {
			let controllers = split.viewControllers
			return (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
		}
		return nil
	}
	
	var representedObjects: [AnyObject]? {
		didSet {
			if !representedObjectArraysAreEqual(oldValue, representedObjects) {
				
				if let representedObjects = representedObjects {
					if representedObjects.count == 1 && representedObjects.first is Feed {
						showFeedNames = false
					}
					else {
						showFeedNames = true
					}
				}
				else {
					showFeedNames = false
				}
				
				fetchArticles()
				if articles.count > 0 {
					tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
				}
				
			}
		}
	}
	
	var articles = ArticleArray() {
		didSet {
			if articles == oldValue {
				return
			}
			if articles.representSameArticlesInSameOrder(as: oldValue) {
				// When the array is the same — same articles, same order —
				// but some data in some of the articles may have changed.
				// Just reload visible cells in this case: don’t call reloadData.
				articleRowMap = [String: Int]()
				reloadAllVisibleCells()
				return
			}
			updateShowAvatars()
			articleRowMap = [String: Int]()
			tableView.reloadData()
		}
	}

	private var articleRowMap = [String: Int]() // articleID: rowIndex
	private var showFeedNames = false {
		didSet {
			if showFeedNames != oldValue {
				updateShowAvatars()
				updateTableViewRowHeight()
			}
		}
	}
	
	private var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortDirectionDidChange()
			}
		}
	}
	
	override func viewDidLoad() {
		
		super.viewDidLoad()
		updateRowHeights()
		
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "showDetail" {
			if let indexPath = tableView.indexPathForSelectedRow {
				let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
				let article = articles[indexPath.row]
				controller.article = article
				controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
				controller.navigationItem.leftItemsSupplementBackButton = true
			}
		}
	}
	
	// MARK Actions

	@IBAction func markAllAsRead(_ sender: Any) {
		
		let title = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		let message = NSLocalizedString("Mark all articles in this timeline as read?", comment: "Mark all articles")
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)
		alertController.addAction(cancelAction)
		
		let markTitle = NSLocalizedString("Mark All Read", comment: "Mark All Read")
		let markAction = UIAlertAction(title: markTitle, style: .default) { [weak self] (action) in
			guard let articles = self?.articles else { return }
			markArticles(Set(articles), statusKey: .read, flag: true)
		}
		alertController.addAction(markAction)
		
		present(alertController, animated: true)
		
	}
	
	// MARK: - Table view

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		
		let article = articles[indexPath.row]
		
		// Set up the star action
		let starTitle = article.status.starred ?
			NSLocalizedString("Unstar", comment: "Unstar") :
			NSLocalizedString("Star", comment: "Star")
		
		let starAction = UIContextualAction(style: .normal, title: starTitle) { (action, view, completionHandler) in
			markArticles(Set([article]), statusKey: .starred, flag: !article.status.starred)
			completionHandler(true)
		}
		
		starAction.image = AppAssets.starClosedImage
		starAction.backgroundColor = AppAssets.starColor
		
		// Set up the read action
		let readTitle = article.status.read ?
			NSLocalizedString("Unread", comment: "Unread") :
			NSLocalizedString("Read", comment: "Read")
		
		let readAction = UIContextualAction(style: .normal, title: readTitle) { (action, view, completionHandler) in
			markArticles(Set([article]), statusKey: .read, flag: !article.status.read)
			completionHandler(true)
		}
		
		readAction.image = AppAssets.circleClosedImage
		readAction.backgroundColor = AppAssets.timelineUnreadCircleColor
		
		let configuration = UISwipeActionsConfiguration(actions: [starAction, readAction])
		return configuration
		
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTimelineTableViewCell
		let article = articles[indexPath.row]

		configureTimelineCell(cell, article: article)
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let article = articles[indexPath.row]
		if !article.status.read {
			markArticles(Set([article]), statusKey: .read, flag: true)
		}
	}
	
	// MARK: Notifications

	@objc func statusesDidChange(_ note: Notification) {
		
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		reloadVisibleCells(for: articles)
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		
		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				
				guard let article = articles.articleAtRow(indexPath.row) else {
					return
				}
				
				if feed == article.feed {
					tableView.reloadRows(at: [indexPath], with: .none)
					return
				}
				
			}
		}

	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		
		guard showAvatars, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}
		
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				
				guard let article = articles.articleAtRow(indexPath.row), let authors = article.authors, !authors.isEmpty else {
					return
				}
				
				for author in authors {
					if author.avatarURL == avatarURL {
						tableView.reloadRows(at: [indexPath], with: .none)
					}
				}

			}
		}
		
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {
		if showAvatars {
			queueReloadVisableCells()
		}
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
	
	@objc func userDefaultsDidChange(_ note: Notification) {
		self.sortDirection = AppDefaults.timelineSortDirection
	}

	// MARK: Reloading
	
	@objc func reloadAllVisibleCells() {
		tableView.beginUpdates()
		performBlockAndRestoreSelection {
			tableView.reloadRows(at: tableView.indexPathsForVisibleRows!, with: .none)
		}
		tableView.endUpdates()
	}
	
	private func reloadVisibleCells(for articles: [Article]) {
		reloadVisibleCells(for: Set(articles.articleIDs()))
	}
	
	private func reloadVisibleCells(for articles: Set<Article>) {
		reloadVisibleCells(for: articles.articleIDs())
	}
	
	private func reloadVisibleCells(for articleIDs: Set<String>) {
		if articleIDs.isEmpty {
			return
		}
		let indexes = indexesForArticleIDs(articleIDs)
		reloadVisibleCells(for: indexes)
	}
	
	private func reloadVisibleCells(for indexes: IndexSet) {
		performBlockAndRestoreSelection {
			tableView.indexPathsForVisibleRows?.forEach { indexPath in
				if indexes.contains(indexPath.row) {
					tableView.reloadRows(at: [indexPath], with: .none)
				}
			}
		}
	}
	
	// MARK: Cell Configuring

	private func calculateRowHeight(showingFeedNames: Bool) -> CGFloat {
		
		let longTitle = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?"
		
		let prototypeID = "prototype"
		let status = ArticleStatus(articleID: prototypeID, read: false, starred: false, userDeleted: false, dateArrived: Date())
		let prototypeArticle = Article(accountID: prototypeID, articleID: prototypeID, feedID: prototypeID, uniqueID: prototypeID, title: longTitle, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: nil, dateModified: nil, authors: nil, attachments: nil, status: status)
		
		let prototypeCellData = MasterTimelineCellData(article: prototypeArticle, showFeedName: showingFeedNames, feedName: "Prototype Feed Name", avatar: nil, showAvatar: false, featuredImage: nil)
		let height = MasterTimelineCellLayout.height(for: 100, cellData: prototypeCellData)
		return height
		
	}
	
	private func updateRowHeights() {
		rowHeightWithFeedName = calculateRowHeight(showingFeedNames: true)
		rowHeightWithoutFeedName = calculateRowHeight(showingFeedNames: false)
		updateTableViewRowHeight()
	}
	
	@objc func fetchAndMergeArticles() {
		
		guard let representedObjects = representedObjects else {
			return
		}
		
		var unsortedArticles = fetchUnsortedArticles(for: representedObjects)
		
		// Merge articles by articleID. For any unique articleID in current articles, add to unsortedArticles.
		let unsortedArticleIDs = unsortedArticles.articleIDs()
		for article in articles {
			if !unsortedArticleIDs.contains(article.articleID) {
				unsortedArticles.insert(article)
			}
		}
		
		updateArticles(with: unsortedArticles)

	}

}

// MARK: Private

private extension MasterTimelineViewController {
	
	func configureTimelineCell(_ cell: MasterTimelineTableViewCell, article: Article) {
		
		var avatar = avatarFor(article)
		if avatar == nil, let feed = article.feed {
			avatar = appDelegate.faviconDownloader.favicon(for: feed)
		}
		let featuredImage = featuredImageFor(article)
		
		cell.cellData = MasterTimelineCellData(article: article, showFeedName: showFeedNames, feedName: article.feed?.nameForDisplay, avatar: avatar, showAvatar: showAvatars, featuredImage: featuredImage)
		
	}
	
	func avatarFor(_ article: Article) -> UIImage? {
		
		if !showAvatars {
			return nil
		}
		
		if let authors = article.authors {
			for author in authors {
				if let image = avatarForAuthor(author) {
					return image
				}
			}
		}
		
		guard let feed = article.feed else {
			return nil
		}
		
		return appDelegate.feedIconDownloader.icon(for: feed)
		
	}
	
	func avatarForAuthor(_ author: Author) -> UIImage? {
		return appDelegate.authorAvatarDownloader.image(for: author)
	}
	
	func featuredImageFor(_ article: Article) -> UIImage? {
		if let url = article.imageURL, let data = appDelegate.imageDownloader.image(for: url) {
			return RSImage(data: data)
		}
		return nil
	}

	func queueReloadVisableCells() {
		CoalescingQueue.standard.add(self, #selector(reloadAllVisibleCells))
	}

	func updateTableViewRowHeight() {
		tableView.rowHeight = currentRowHeight
		tableView.estimatedRowHeight = currentRowHeight
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

	func representedObjectArraysAreEqual(_ objects1: [AnyObject]?, _ objects2: [AnyObject]?) -> Bool {
		
		if objects1 == nil && objects2 == nil {
			return true
		}
		guard let objects1 = objects1, let objects2 = objects2 else {
			return false
		}
		if objects1.count != objects2.count {
			return false
		}
		
		var ix = 0
		for oneObject in objects1 {
			if oneObject !== objects2[ix] {
				return false
			}
			ix += 1
		}
		return true
	}

	// MARK: Fetching Articles
	
	func fetchArticles() {
		
		guard let representedObjects = representedObjects else {
			emptyTheTimeline()
			return
		}
		
		let fetchedArticles = fetchUnsortedArticles(for: representedObjects)
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

	func performBlockAndRestoreSelection(_ block: (() -> Void)) {
		let indexPaths = tableView.indexPathsForSelectedRows
		block()
		indexPaths?.forEach { [weak self] indexPath in
			self?.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
		}
	}

	func updateArticles(with unsortedArticles: Set<Article>) {
		
		let sortedArticles = Array(unsortedArticles).sortedByDate(sortDirection)
		if articles != sortedArticles {
			articles = sortedArticles
		}
		
	}
	
	func fetchUnsortedArticles(for representedObjects: [Any]) -> Set<Article> {
		
		var fetchedArticles = Set<Article>()
		
		for object in representedObjects {
			
			if let articleFetcher = object as? ArticleFetcher {
				fetchedArticles.formUnion(articleFetcher.fetchArticles())
			}
		}
		
		return fetchedArticles
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
		MasterTimelineViewController.fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticles))
	}
	
	func representedObjectsContainsAnyPseudoFeed() -> Bool {
		guard let representedObjects = representedObjects else {
			return false
		}
		for representedObject in representedObjects {
			if representedObject is PseudoFeed {
				return true
			}
		}
		return false
	}
	
	func representedObjectsContainsAnyFeed(_ feeds: Set<Feed>) -> Bool {
		
		// Return true if there’s a match or if a folder contains (recursively) one of feeds
		
		guard let representedObjects = representedObjects else {
			return false
		}
		for representedObject in representedObjects {
			if let feed = representedObject as? Feed {
				for oneFeed in feeds {
					if feed.feedID == oneFeed.feedID || feed.url == oneFeed.url {
						return true
					}
				}
			}
			else if let folder = representedObject as? Folder {
				for oneFeed in feeds {
					if folder.hasFeed(with: oneFeed.feedID) || folder.hasFeed(withURL: oneFeed.url) {
						return true
					}
				}
			}
		}
		return false
	}
	
}
