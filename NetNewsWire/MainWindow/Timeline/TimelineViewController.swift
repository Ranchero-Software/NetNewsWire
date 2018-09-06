//
//  TimelineViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Articles
import Account

class TimelineViewController: NSViewController, UndoableCommandRunner {

	@IBOutlet var tableView: TimelineTableView!
	@IBOutlet var contextualMenuDelegate: TimelineContextualMenuDelegate?
	@IBOutlet var dataSource: TimelineDataSource!

	var selectedArticles: [Article] {
		return Array(articles.articlesForIndexes(tableView.selectedRowIndexes))
	}

	var hasAtLeastOneSelectedArticle: Bool {
		return tableView.selectedRow != -1
	}

	var articles = ArticleArray() {
		didSet {
			if articles != oldValue {
				dataSource.articles = articles
				updateShowAvatars()
				tableView.reloadData()
			}
		}
	}

	var undoableCommands = [UndoableCommand]()
	private var cellAppearance: TimelineCellAppearance!
	private var cellAppearanceWithAvatar: TimelineCellAppearance!
	private var showFeedNames = false {
		didSet {
			if showFeedNames != oldValue {
				updateShowAvatars()
				updateTableViewRowHeight()
			}
		}
	}

	private var showAvatars = false
	private var rowHeightWithFeedName: CGFloat = 0.0
	private var rowHeightWithoutFeedName: CGFloat = 0.0

	private var currentRowHeight: CGFloat {
		return showFeedNames ? rowHeightWithFeedName : rowHeightWithoutFeedName
	}

	private var didRegisterForNotifications = false
	static let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5)

	private var sortDirection = AppDefaults.shared.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortDirectionDidChange()
			}
		}
	}
	private var fontSize: FontSize = AppDefaults.shared.timelineFontSize {
		didSet {
			if fontSize != oldValue {
				fontSizeDidChange()
			}
		}
	}

	private var representedObjects: [AnyObject]? {
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

				postTimelineSelectionDidChangeNotification(nil)
				articles = ArticleArray()
				fetchArticles()
				if articles.count > 0 {
					tableView.scrollRowToVisible(0)
				}
			}
		}
	}

	private var oneSelectedArticle: Article? {
		return selectedArticles.count == 1 ? selectedArticles.first : nil
	}

	override func viewDidLoad() {

		cellAppearance = TimelineCellAppearance(theme: appDelegate.currentTheme, showAvatar: false, fontSize: fontSize)
		cellAppearanceWithAvatar = TimelineCellAppearance(theme: appDelegate.currentTheme, showAvatar: true, fontSize: fontSize)

		updateRowHeights()
		tableView.rowHeight = currentRowHeight
		tableView.target = self
		tableView.doubleAction = #selector(openArticleInBrowser(_:))
		tableView.setDraggingSourceOperationMask(.copy, forLocal: false)

		if !didRegisterForNotifications {

			NotificationCenter.default.addObserver(self, selector: #selector(sidebarSelectionDidChange(_:)), name: .SidebarSelectionDidChange, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .ImageDidBecomeAvailable, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(imageDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

				didRegisterForNotifications = true
		}
	}

	// MARK: Appearance Change

	private func fontSizeDidChange() {

		cellAppearance = TimelineCellAppearance(theme: appDelegate.currentTheme, showAvatar: false, fontSize: fontSize)
		cellAppearanceWithAvatar = TimelineCellAppearance(theme: appDelegate.currentTheme, showAvatar: true, fontSize: fontSize)
		updateRowHeights()
		performBlockAndRestoreSelection {
			tableView.reloadData()
		}
	}

	// MARK: - API
	
	func markAllAsRead() {

		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, markingRead: true, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}

	func canMarkAllAsRead() -> Bool {

		return articles.canMarkAllAsRead()
	}

	func canMarkSelectedArticlesAsRead() -> Bool {

		return selectedArticles.canMarkAllAsRead()
	}

	// MARK: - Actions

	@objc func openArticleInBrowser(_ sender: Any?) {
		
		if let link = oneSelectedArticle?.preferredLink {
			Browser.open(link)
		}
	}
	
	@IBAction func toggleStatusOfSelectedArticles(_ sender: Any?) {
	
		guard !selectedArticles.isEmpty else {
			return
		}
		let articles = selectedArticles
		let status = articles.first!.status
		let markAsRead = !status.read

		if markAsRead {
			markSelectedArticlesAsRead(sender)
		}
		else {
			markSelectedArticlesAsUnread(sender)
		}
	}

	@IBAction func markSelectedArticlesAsRead(_ sender: Any?) {

		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: selectedArticles, markingRead: true, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}
	
	@IBAction func markSelectedArticlesAsUnread(_ sender: Any?) {
		
		guard let undoManager = undoManager, let markUnreadCommand = MarkStatusCommand(initialArticles: selectedArticles, markingRead: false, undoManager: undoManager) else {
			return
		}
		runCommand(markUnreadCommand)
	}

	@IBAction func copy(_ sender: Any?) {

		NSPasteboard.general.copyObjects(selectedArticles)
	}

	func toggleStarredStatusForSelectedArticles() {

		// If any one of the selected articles is not starred, then star them.
		// If all articles are starred, then unstar them.

		let commandStatus = markStarredCommandStatus()
		let starring: Bool
		switch commandStatus {
		case .canMark:
			starring = true
		case .canUnmark:
			starring = false
		case .canDoNothing:
			return
		}

		guard let undoManager = undoManager, let markStarredCommand = MarkStatusCommand(initialArticles: selectedArticles, markingStarred: starring, undoManager: undoManager) else {
			return
		}
		runCommand(markStarredCommand)
	}

	func markStarredCommandStatus() -> MarkCommandValidationStatus {

		return MarkCommandValidationStatus.statusFor(selectedArticles) { $0.anyArticleIsUnstarred() }
	}

	func markReadCommandStatus() -> MarkCommandValidationStatus {

		return MarkCommandValidationStatus.statusFor(selectedArticles) { $0.anyArticleIsUnread() }
	}

	func markOlderArticlesRead() {
		markOlderArticlesRead(selectedArticles)
	}

	func canMarkOlderArticlesAsRead() -> Bool {
		return !selectedArticles.isEmpty
	}

	func markOlderArticlesRead(_ selectedArticles: [Article]) {
		// Mark articles older than the selectedArticles(s) as read.

		var cutoffDate: Date? = nil
		for article in selectedArticles {
			if cutoffDate == nil {
				cutoffDate = article.logicalDatePublished
			}
			else if cutoffDate! > article.logicalDatePublished {
				cutoffDate = article.logicalDatePublished
			}
		}
		if cutoffDate == nil {
			return
		}

		let articlesToMark = articles.filter { $0.logicalDatePublished < cutoffDate! }
		if articlesToMark.isEmpty {
			return
		}

		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articlesToMark, markingRead: true, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}

	// MARK: - Navigation
	
	func goToNextUnread() {
		
		guard let ix = indexOfNextUnreadArticle() else {
			return
		}
		NSCursor.setHiddenUntilMouseMoves(true)
		tableView.rs_selectRow(ix)
		tableView.scrollTo(row: ix)
	}
	
	func canGoToNextUnread() -> Bool {
		
		guard let _ = indexOfNextUnreadArticle() else {
			return false
		}
		return true
	}
	
	func indexOfNextUnreadArticle() -> Int? {

		return articles.rowOfNextUnreadArticle(tableView.selectedRow)
	}

	func focus() {

		guard let window = tableView.window else {
			return
		}

		window.makeFirstResponderUnlessDescendantIsFirstResponder(tableView)
		if !hasAtLeastOneSelectedArticle && articles.count > 0 {
			tableView.rs_selectRowAndScrollToVisible(0)
		}
	}

	// MARK: - Notifications

	@objc func sidebarSelectionDidChange(_ notification: Notification) {

		guard let userInfo = notification.userInfo else {
			return
		}
		guard let sidebarView = userInfo[UserInfoKey.view] as? NSView, sidebarView.window === tableView.window else {
			return
		}

		if let objects = userInfo[UserInfoKey.objects] as? [AnyObject] {
			representedObjects = objects
		}
		else {
			representedObjects = nil
		}
	}
	
	@objc func statusesDidChange(_ note: Notification) {

		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		reloadCellsForArticleIDs(articles.articleIDs())
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {

		guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		let articlesToReload = articles.filter { (article) -> Bool in
			return feed == article.feed
		}
		reloadCellsForArticles(articlesToReload)
	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {

		guard showAvatars, let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
			return
		}

		let indexesToReload = tableView.indexesOfAvailableRowsPassingTest { (row) -> Bool in
			guard let article = articles.articleAtRow(row), let authors = article.authors, !authors.isEmpty else {
				return false
			}
			for author in authors {
				if author.avatarURL == avatarURL {
					return true
				}
			}
			return false
		}
		if let indexesToReload = indexesToReload {
			reloadCells(for: indexesToReload)
		}
	}

	@objc func imageDidBecomeAvailable(_ note: Notification) {

		if showAvatars {
			queueReloadAvailableCells()
		}
	}

	@objc func accountDidDownloadArticles(_ note: Notification) {

		guard let feeds = note.userInfo?[Account.UserInfoKey.feeds] as? Set<Feed> else {
			return
		}

		let shouldFetchAndMergeArticles = representedObjectsContainsAnyFeed(feeds)
		if shouldFetchAndMergeArticles {
			queueFetchAndMergeArticles()
		}
	}

	@objc func userDefaultsDidChange(_ note: Notification) {

		self.fontSize = AppDefaults.shared.timelineFontSize
		self.sortDirection = AppDefaults.shared.timelineSortDirection
	}

	// MARK: - Reloading Data

	private func cellForRowView(_ rowView: NSView) -> NSView? {
		
		for oneView in rowView.subviews where oneView is TimelineTableCellView {
			return oneView
		}
		return nil
	}
	
	private func reloadCellsForArticles(_ articles: [Article]) {
		
		reloadCellsForArticleIDs(Set(articles.articleIDs()))
	}
	
	private func reloadCellsForArticleIDs(_ articleIDs: Set<String>) {

		if articleIDs.isEmpty {
			return
		}
		let indexes = articles.indexesForArticleIDs(articleIDs)
		reloadCells(for: indexes)
	}

	private func reloadCells(for indexes: IndexSet) {

		if indexes.isEmpty {
			return
		}
		tableView.reloadData(forRowIndexes: indexes, columnIndexes: NSIndexSet(index: 0) as IndexSet)
	}
	
	// MARK: - Cell Configuring

	private func calculateRowHeight(showingFeedNames: Bool) -> CGFloat {

		let longTitle = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?"
		let prototypeID = "prototype"
		let status = ArticleStatus(articleID: prototypeID, read: false, starred: false, userDeleted: false, dateArrived: Date())
		let prototypeArticle = Article(accountID: prototypeID, articleID: prototypeID, feedID: prototypeID, uniqueID: prototypeID, title: longTitle, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: nil, dateModified: nil, authors: nil, attachments: nil, status: status)
		
		let prototypeCellData = TimelineCellData(article: prototypeArticle, appearance: cellAppearance, showFeedName: showingFeedNames, feedName: "Prototype Feed Name", avatar: nil, showAvatar: false, featuredImage: nil)
		let height = TimelineCellLayout.height(for: 100, cellData: prototypeCellData, appearance: cellAppearance)
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

		performBlockAndRestoreSelection {

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
}

// MARK: NSUserInterfaceValidations

extension TimelineViewController: NSUserInterfaceValidations {

	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {

		if item.action == #selector(copy(_:)) {
			return NSPasteboard.general.canCopyAtLeastOneObject(selectedArticles)
		}
		return true
	}
}

// MARK: - NSTableViewDelegate

extension TimelineViewController: NSTableViewDelegate {

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {

		let rowView: TimelineTableRowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineRow"), owner: self) as! TimelineTableRowView
		rowView.cellAppearance = showAvatars ? cellAppearanceWithAvatar: cellAppearance
		return rowView
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

		let cell: TimelineTableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineCell"), owner: self) as! TimelineTableCellView
		cell.cellAppearance = showAvatars ? cellAppearanceWithAvatar: cellAppearance

		if let article = articles.articleAtRow(row) {
			configureTimelineCell(cell, article: article)
		}
		else {
			makeTimelineCellEmpty(cell)
		}

		return cell
	}

	func tableViewSelectionDidChange(_ notification: Notification) {

		tableView.redrawGrid()

		if selectedArticles.isEmpty {
			postTimelineSelectionDidChangeNotification(nil)
			return
		}

		if selectedArticles.count == 1 {
			let article = selectedArticles.first!
			if !article.status.read {
				markArticles(Set([article]), statusKey: .read, flag: true)
			}
		}

		postTimelineSelectionDidChangeNotification(selectedArticles)
	}

	private func postTimelineSelectionDidChangeNotification(_ selectedArticles: ArticleArray?) {

		var userInfo = UserInfoDictionary()
		if let selectedArticles = selectedArticles {
			userInfo[UserInfoKey.articles] = selectedArticles
		}
		userInfo[UserInfoKey.view] = tableView

		NotificationCenter.default.post(name: .TimelineSelectionDidChange, object: self, userInfo: userInfo)
	}

	private func configureTimelineCell(_ cell: TimelineTableCellView, article: Article) {

		cell.objectValue = article

//		let favicon = showFeedNames ? article.feed?.smallIcon : nil
		var avatar = avatarFor(article)
		if avatar == nil, let feed = article.feed {
			avatar = appDelegate.faviconDownloader.favicon(for: feed)
		}
		let featuredImage = featuredImageFor(article)

		cell.cellData = TimelineCellData(article: article, appearance: cellAppearance, showFeedName: showFeedNames, feedName: article.feed?.nameForDisplay, avatar: avatar, showAvatar: showAvatars, featuredImage: featuredImage)
	}

	private func avatarFor(_ article: Article) -> NSImage? {

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

	private func avatarForAuthor(_ author: Author) -> NSImage? {

		return appDelegate.authorAvatarDownloader.image(for: author)
	}

	private func featuredImageFor(_ article: Article) -> NSImage? {

		if let url = article.imageURL {
			return appDelegate.imageDownloader.image(for: url)
		}
		return nil
	}

	private func makeTimelineCellEmpty(_ cell: TimelineTableCellView) {

		cell.objectValue = nil
		cell.cellData = TimelineCellData()
	}
}

// MARK: - Private

private extension TimelineViewController {

	@objc func reloadAvailableCells() {

		if let indexesToReload = tableView.indexesOfAvailableRows() {
			reloadCells(for: indexesToReload)
		}
	}

	func queueReloadAvailableCells() {

		CoalescingQueue.standard.add(self, #selector(reloadAvailableCells))
	}

	func updateTableViewRowHeight() {

		tableView.rowHeight = currentRowHeight
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

	func emptyTheTimeline() {

		if !articles.isEmpty {
			articles = [Article]()
		}
	}

	func sortDirectionDidChange() {

		performBlockAndRestoreSelection {
			let unsortedArticles = Set(articles)
			updateArticles(with: unsortedArticles)
		}
	}

	func selectedArticleIDs() -> [String] {

		return selectedArticles.articleIDs()
	}

	func restoreSelection(_ articleIDs: [String]) {

		selectArticles(articleIDs)
		if tableView.selectedRow != -1 {
			tableView.scrollRowToVisible(tableView.selectedRow)
		}
	}

	func performBlockAndRestoreSelection(_ block: (() -> Void)) {

		let savedSelection = selectedArticleIDs()
		block()
		restoreSelection(savedSelection)
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

	func selectArticles(_ articleIDs: [String]) {

		let indexesToSelect = articles.indexesForArticleIDs(Set(articleIDs))
		if indexesToSelect.isEmpty {
			tableView.deselectAll(self)
			return
		}
		tableView.selectRowIndexes(indexesToSelect, byExtendingSelection: false)
	}

	func queueFetchAndMergeArticles() {

		TimelineViewController.fetchAndMergeArticlesQueue.add(self, #selector(fetchAndMergeArticles))
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

