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

protocol TimelineDelegate: class  {
	func timelineSelectionDidChange(_: TimelineViewController, selectedArticles: [Article]?)
}

final class TimelineViewController: NSViewController, UndoableCommandRunner, UnreadCountProvider {

	@IBOutlet var tableView: TimelineTableView!

	var representedObjects: [AnyObject]? {
		didSet {
			if !representedObjectArraysAreEqual(oldValue, representedObjects) {
				unreadCount = 0
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

				selectionDidChange(nil)
				if showsSearchResults {
					fetchAndReplaceArticlesAsync()
				}
				else {
					fetchAndReplaceArticlesSync()
					if articles.count > 0 {
						tableView.scrollRowToVisible(0)
					}
					updateUnreadCount()
				}
			}
		}
	}

	private weak var delegate: TimelineDelegate?
	var sharingServiceDelegate: NSSharingServiceDelegate?

	var showsSearchResults = false
	var selectedArticles: [Article] {
		return Array(articles.articlesForIndexes(tableView.selectedRowIndexes))
	}

	var hasAtLeastOneSelectedArticle: Bool {
		return tableView.selectedRow != -1
	}

	var articles = ArticleArray() {
		didSet {
			defer {
				updateUnreadCount()
			}
			if articles == oldValue {
				return
			}
			if articles.representSameArticlesInSameOrder(as: oldValue) {
				// When the array is the same — same articles, same order —
				// but some data in some of the articles may have changed.
				// Just reload visible cells in this case: don’t call reloadData.
				articleRowMap = [String: Int]()
				reloadVisibleCells()
				return
			}
			updateShowAvatars()
			articleRowMap = [String: Int]()
			tableView.reloadData()
		}
	}

	var unreadCount: Int = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	var undoableCommands = [UndoableCommand]()
	private var fetchSerialNumber = 0
	private let fetchRequestQueue = FetchRequestQueue()
	private var articleRowMap = [String: Int]() // articleID: rowIndex
	private var cellAppearance: TimelineCellAppearance!
	private var cellAppearanceWithAvatar: TimelineCellAppearance!
	private var showFeedNames = false {
		didSet {
			if showFeedNames != oldValue {
				updateShowAvatars()
				updateTableViewRowHeight()
				reloadVisibleCells()
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
	static let fetchAndMergeArticlesQueue = CoalescingQueue(name: "Fetch and Merge Articles", interval: 0.5, maxInterval: 2.0)

	private var sortDirection = AppDefaults.timelineSortDirection {
		didSet {
			if sortDirection != oldValue {
				sortParametersDidChange()
			}
		}
	}
	private var groupByFeed = AppDefaults.timelineGroupByFeed {
		didSet {
			if groupByFeed != oldValue {
				sortParametersDidChange()
			}
		}
	}
	private var fontSize: FontSize = AppDefaults.timelineFontSize {
		didSet {
			if fontSize != oldValue {
				fontSizeDidChange()
			}
		}
	}

	private var oneSelectedArticle: Article? {
		return selectedArticles.count == 1 ? selectedArticles.first : nil
	}

	private let keyboardDelegate = TimelineKeyboardDelegate()
	private var timelineShowsSeparatorsObserver: NSKeyValueObservation?

	convenience init(delegate: TimelineDelegate) {
		self.init(nibName: "TimelineTableView", bundle: nil)
		self.delegate = delegate
		self.startObservingUserDefaults()
	}
	
	override func viewDidLoad() {
		cellAppearance = TimelineCellAppearance(showAvatar: false, fontSize: fontSize)
		cellAppearanceWithAvatar = TimelineCellAppearance(showAvatar: true, fontSize: fontSize)

		updateRowHeights()
		tableView.rowHeight = currentRowHeight
		tableView.target = self
		tableView.doubleAction = #selector(openArticleInBrowser(_:))
		tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
		tableView.keyboardDelegate = keyboardDelegate
		
		if !didRegisterForNotifications {
			NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(accountDidDownloadArticles(_:)), name: .AccountDidDownloadArticles, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidAddAccount, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .UserDidDeleteAccount, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

			didRegisterForNotifications = true
		}
	}
	
	override func viewDidAppear() {
		sharingServiceDelegate = SharingServiceDelegate(self.view.window)
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

	func representsThisObjectOnly(_ object: AnyObject) -> Bool {
		guard let representedObjects = representedObjects else {
			return false
		}
		if representedObjects.count != 1 {
			return false
		}
		return representedObjects.first! === object
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

	@IBAction func selectNextUp(_ sender: Any?) {
		guard let lastSelectedRow = tableView.selectedRowIndexes.last else {
			return
		}
		
		let nextRowIndex = lastSelectedRow - 1
		if nextRowIndex <= 0 {
			tableView.scrollTo(row: 0, extraHeight: 0)
		}
		
		tableView.rs_selectRow(nextRowIndex)
		
		let followingRowIndex = nextRowIndex - 1
		if followingRowIndex < 0 {
			return
		}
		
		tableView.scrollToRowIfNotVisible(followingRowIndex)
		
	}
	
	@IBAction func selectNextDown(_ sender: Any?) {
		guard let firstSelectedRow = tableView.selectedRowIndexes.first else {
			return
		}
		
		let tableMaxIndex = tableView.numberOfRows - 1
		let nextRowIndex = firstSelectedRow + 1
		if nextRowIndex >= tableMaxIndex {
			tableView.scrollTo(row: tableMaxIndex, extraHeight: 0)
		}
		
		tableView.rs_selectRow(nextRowIndex)
		
		let followingRowIndex = nextRowIndex + 1
		if followingRowIndex > tableMaxIndex {
			return
		}

		tableView.scrollToRowIfNotVisible(followingRowIndex)

	}
	
	func toggleReadStatusForSelectedArticles() {
		// If any one of the selected articles is unread, then mark them as read.
		// If all articles are read, then mark them as unread them.
		
		let commandStatus = markReadCommandStatus()
		let markingRead: Bool
		switch commandStatus {
		case .canMark:
			markingRead = true
		case .canUnmark:
			markingRead = false
		case .canDoNothing:
			return
		}
		
		guard let undoManager = undoManager, let markStarredCommand = MarkStatusCommand(initialArticles: selectedArticles, markingRead: markingRead, undoManager: undoManager) else {
			return
		}
		
		runCommand(markStarredCommand)
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

	@objc func statusesDidChange(_ note: Notification) {
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		reloadVisibleCells(for: articles)
		updateUnreadCount()
	}

	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
		guard showAvatars, let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		let indexesToReload = tableView.indexesOfAvailableRowsPassingTest { (row) -> Bool in
			guard let article = articles.articleAtRow(row) else {
				return false
			}
			return feed == article.feed
		}
		if let indexesToReload = indexesToReload {
			reloadCells(for: indexesToReload)
		}
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

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		if showAvatars {
			queueReloadAvailableCells()
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

	@objc func accountStateDidChange(_ note: Notification) {
		if representedObjectsContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesAsync()
		}
	}
	
	@objc func accountsDidChange(_ note: Notification) {
		if representedObjectsContainsAnyPseudoFeed() {
			fetchAndReplaceArticlesAsync()
		}
	}

	@objc func containerChildrenDidChange(_ note: Notification) {
		if representedObjectsContainsAnyPseudoFeed() || representedObjectsContainAnyFolder() {
			fetchAndReplaceArticlesAsync()
		}
	}

	@objc func userDefaultsDidChange(_ note: Notification) {
		self.fontSize = AppDefaults.timelineFontSize
		self.sortDirection = AppDefaults.timelineSortDirection
		self.groupByFeed = AppDefaults.timelineGroupByFeed
	}
	
	// MARK: - Reloading Data

	private func cellForRowView(_ rowView: NSView) -> NSView? {
		for oneView in rowView.subviews where oneView is TimelineTableCellView {
			return oneView
		}
		return nil
	}

	private func reloadVisibleCells() {
		guard let indexes = tableView.indexesOfAvailableRows() else {
			return
		}
		reloadVisibleCells(for: indexes)
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
		let indexesToReload = tableView.indexesOfAvailableRowsPassingTest { (row) -> Bool in
			return indexes.contains(row)
		}
		if let indexesToReload = indexesToReload {
			reloadCells(for: indexesToReload)
		}
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
		
		let prototypeCellData = TimelineCellData(article: prototypeArticle, showFeedName: showingFeedNames, feedName: "Prototype Feed Name", avatar: nil, showAvatar: false, featuredImage: nil)
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

		fetchUnsortedArticlesAsync(for: representedObjects) { [weak self] (unsortedArticles) in
			// Merge articles by articleID. For any unique articleID in current articles, add to unsortedArticles.
			guard let strongSelf = self else {
				return
			}
			let unsortedArticleIDs = unsortedArticles.articleIDs()
			var updatedArticles = unsortedArticles
			for article in strongSelf.articles {
				if !unsortedArticleIDs.contains(article.articleID) {
					updatedArticles.insert(article)
				}
			}
			strongSelf.performBlockAndRestoreSelection {
				strongSelf.replaceArticles(with: updatedArticles)
			}
		}
	}
}

// MARK: - NSMenuDelegate

extension TimelineViewController: NSMenuDelegate {

	public func menuNeedsUpdate(_ menu: NSMenu) {
		menu.removeAllItems()
		guard let contextualMenu = contextualMenuForClickedRows() else {
			return
		}
		menu.takeItems(from: contextualMenu)
	}
}

// MARK: - NSUserInterfaceValidations

extension TimelineViewController: NSUserInterfaceValidations {

	func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
		if item.action == #selector(openArticleInBrowser(_:)) {
			let currentLink = oneSelectedArticle?.preferredLink
			return currentLink != nil
		}

		if item.action == #selector(copy(_:)) {
			return NSPasteboard.general.canCopyAtLeastOneObject(selectedArticles)
		}

		return true
	}
}

// MARK: - NSTableViewDataSource

extension TimelineViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return articles.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return articles.articleAtRow(row) ?? nil
	}

	func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
		guard let article = articles.articleAtRow(row) else {
			return nil
		}
		return ArticlePasteboardWriter(article: article)
	}
}

// MARK: - NSTableViewDelegate

extension TimelineViewController: NSTableViewDelegate {
	private static let rowViewIdentifier = NSUserInterfaceItemIdentifier(rawValue: "timelineRow")

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		if let rowView: TimelineTableRowView = tableView.makeView(withIdentifier: TimelineViewController.rowViewIdentifier, owner: nil) as? TimelineTableRowView {
			return rowView
		}
		let rowView = TimelineTableRowView()
		rowView.identifier = TimelineViewController.rowViewIdentifier
		return rowView
	}

	private static let timelineCellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "timelineCell")

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

		func configure(_ cell: TimelineTableCellView) {
			cell.cellAppearance = showAvatars ? cellAppearanceWithAvatar : cellAppearance
			if let article = articles.articleAtRow(row) {
				configureTimelineCell(cell, article: article)
			}
			else {
				makeTimelineCellEmpty(cell)
			}
		}

		if let cell = tableView.makeView(withIdentifier: TimelineViewController.timelineCellIdentifier, owner: nil) as? TimelineTableCellView {
			configure(cell)
			return cell
		}

		let cell = TimelineTableCellView()
		cell.identifier = TimelineViewController.timelineCellIdentifier
		configure(cell)
		return cell
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		if selectedArticles.isEmpty {
			selectionDidChange(nil)
			return
		}

		if selectedArticles.count == 1 {
			let article = selectedArticles.first!
			if !article.status.read {
				markArticles(Set([article]), statusKey: .read, flag: true)
			}
		}

		selectionDidChange(selectedArticles)
	}

	private func selectionDidChange(_ selectedArticles: ArticleArray?) {
		delegate?.timelineSelectionDidChange(self, selectedArticles: selectedArticles)
	}

	private func configureTimelineCell(_ cell: TimelineTableCellView, article: Article) {
		cell.objectValue = article
		let avatar = article.avatarImage()
		cell.cellData = TimelineCellData(article: article, showFeedName: showFeedNames, feedName: article.feed?.nameForDisplay, avatar: avatar, showAvatar: showAvatars, featuredImage: nil)
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

		if let feedIcon = appDelegate.feedIconDownloader.icon(for: feed) {
			return feedIcon
		}

		if let favicon = appDelegate.faviconDownloader.faviconAsAvatar(for: feed) {
			return favicon
		}
		
		return FaviconGenerator.favicon(feed)
	}

	private func avatarForAuthor(_ author: Author) -> NSImage? {
		return appDelegate.authorAvatarDownloader.image(for: author)
	}

	private func makeTimelineCellEmpty(_ cell: TimelineTableCellView) {
		cell.objectValue = nil
		cell.cellData = TimelineCellData()
	}
}

// MARK: - Private

private extension TimelineViewController {

	func startObservingUserDefaults() {
		assert(timelineShowsSeparatorsObserver == nil)
		timelineShowsSeparatorsObserver = UserDefaults.standard.observe(\UserDefaults.CorreiaSeparators) { [weak self] (_, _) in
			guard let self = self, self.isViewLoaded else { return }
			self.tableView.enumerateAvailableRowViews { (rowView, index) in
				if let cellView = rowView.view(atColumn: 0) as? TimelineTableCellView {
					cellView.timelineShowsSeparatorsDefaultDidChange()
				}
			}
		}
	}
	
	@objc func reloadAvailableCells() {
		if let indexesToReload = tableView.indexesOfAvailableRows() {
			reloadCells(for: indexesToReload)
		}
	}

	func updateUnreadCount() {
		var count = 0
		for article in articles {
			if !article.status.read {
				count += 1
			}
		}
		unreadCount = count
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

	func sortParametersDidChange() {
		performBlockAndRestoreSelection {
			let unsortedArticles = Set(articles)
			replaceArticles(with: unsortedArticles)
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

	func row(for articleID: String) -> Int? {
		updateArticleRowMapIfNeeded()
		return articleRowMap[articleID]
	}

	func row(for article: Article) -> Int? {
		return row(for: article.articleID)
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

	// MARK: - Appearance Change

	private func fontSizeDidChange() {
		cellAppearance = TimelineCellAppearance(showAvatar: false, fontSize: fontSize)
		cellAppearanceWithAvatar = TimelineCellAppearance(showAvatar: true, fontSize: fontSize)
		updateRowHeights()
		performBlockAndRestoreSelection {
			tableView.reloadData()
		}
	}

	// MARK: - Fetching Articles

	func fetchAndReplaceArticlesSync() {
		// To be called when the user has made a change of selection in the sidebar.
		// It blocks the main thread, so that there’s no async delay,
		// so that the entire display refreshes at once.
		// It’s a better user experience this way.
		cancelPendingAsyncFetches()
		guard let representedObjects = representedObjects else {
			emptyTheTimeline()
			return
		}
		let fetchedArticles = fetchUnsortedArticlesSync(for: representedObjects)
		replaceArticles(with: fetchedArticles)
	}

	func fetchAndReplaceArticlesAsync() {
		// To be called when we need to do an entire fetch, but an async delay is okay.
		// Example: we have the Today feed selected, and the calendar day just changed.
		cancelPendingAsyncFetches()
		guard let representedObjects = representedObjects else {
			emptyTheTimeline()
			return
		}
		fetchUnsortedArticlesAsync(for: representedObjects) { [weak self] (articles) in
			self?.replaceArticles(with: articles)
		}
	}

	func cancelPendingAsyncFetches() {
		fetchSerialNumber += 1
		fetchRequestQueue.cancelAllRequests()
	}

	func replaceArticles(with unsortedArticles: Set<Article>) {
		articles = Array(unsortedArticles).sortedByDate(sortDirection, groupByFeed: groupByFeed)
	}

	func fetchUnsortedArticlesSync(for representedObjects: [Any]) -> Set<Article> {
		cancelPendingAsyncFetches()
		let articleFetchers = representedObjects.compactMap{ $0 as? ArticleFetcher }
		if articleFetchers.isEmpty {
			return Set<Article>()
		}

		var fetchedArticles = Set<Article>()
		for articleFetcher in articleFetchers {
			fetchedArticles.formUnion(articleFetcher.fetchArticles())
		}
		return fetchedArticles
	}

	func fetchUnsortedArticlesAsync(for representedObjects: [Any], callback: @escaping ArticleSetBlock) {
		// The callback will *not* be called if the fetch is no longer relevant — that is,
		// if it’s been superseded by a newer fetch, or the timeline was emptied, etc., it won’t get called.
		precondition(Thread.isMainThread)
		cancelPendingAsyncFetches()
		let fetchOperation = FetchRequestOperation(id: fetchSerialNumber, representedObjects: representedObjects) { [weak self] (articles, operation) in
			precondition(Thread.isMainThread)
			guard !operation.isCanceled, let strongSelf = self, operation.id == strongSelf.fetchSerialNumber else {
				return
			}
			callback(articles)
		}
		fetchRequestQueue.add(fetchOperation)
	}

	func selectArticles(_ articleIDs: [String]) {
		let indexesToSelect = indexesForArticleIDs(Set(articleIDs))
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

	func representedObjectsContainsAnyPseudoFeed() -> Bool {
		return representedObjects?.contains(where: { $0 is PseudoFeed}) ?? false
	}

	func representedObjectsContainsTodayFeed() -> Bool {
		return representedObjects?.contains(where: { $0 === SmartFeedsController.shared.todayFeed }) ?? false
	}

	func representedObjectsContainAnyFolder() -> Bool {
		return representedObjects?.contains(where: { $0 is Folder }) ?? false
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
