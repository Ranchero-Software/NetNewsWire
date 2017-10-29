//
//  TimelineViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSTextDrawing
import RSTree
import Data
import Account

class TimelineViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, KeyboardDelegate {

	@IBOutlet var tableView: TimelineTableView!
	private var undoableCommands = [UndoableCommand]()
	var didRegisterForNotifications = false
	var fontSize: FontSize = AppDefaults.shared.timelineFontSize {
		didSet {
			fontSizeDidChange()
		}
	}
	var cellAppearance: TimelineCellAppearance!

	private var articles = [Article]() {
		didSet {
			tableView.reloadData()
		}
	}

	private var representedObjects: [AnyObject]? {
		didSet {
			if !representedObjectArraysAreEqual(oldValue, representedObjects) {
				fetchArticles()
				if articles.count > 0 {
					tableView.scrollRowToVisible(0)
				}
			}
		}
	}

	private var showFeedNames: Bool {

//		if let _ = node?.representedObject as? Feed {
			return false
//		}
//		return true
	}

	var selectedArticles: [Article] {
		get {
			return Array(articlesForIndexes(tableView.selectedRowIndexes))
		}
	}

	private var oneSelectedArticle: Article? {
		get {
			return selectedArticles.count == 1 ? selectedArticles.first : nil
		}
	}

	private let timelineFontSizeKVOKey = "values.{AppDefaults.Key.timelineFontSize}"

	override func viewDidLoad() {

		cellAppearance = TimelineCellAppearance(theme: currentTheme, fontSize: fontSize)
		tableView.rowHeight = calculateRowHeight()

		tableView.target = self
		tableView.doubleAction = #selector(openArticleInBrowser(_:))
		
		tableView.keyboardDelegate = self
		
		if !didRegisterForNotifications {

			NotificationCenter.default.addObserver(self, selector: #selector(sidebarSelectionDidChange(_:)), name: .SidebarSelectionDidChange, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)

			NSUserDefaultsController.shared.addObserver(self, forKeyPath: timelineFontSizeKVOKey, options: NSKeyValueObservingOptions(rawValue: 0), context: nil)

			didRegisterForNotifications = true
		}
	}

	// MARK: KVO

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		
		if let keyPath = keyPath {

			switch (keyPath) {

			case timelineFontSizeKVOKey:
				fontSizeInDefaultsDidChange()
				return
			default:
				break
			}
		}

		super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
	}

	// MARK: Appearance Change

	private func fontSizeDidChange() {

		cellAppearance = TimelineCellAppearance(theme: currentTheme, fontSize: fontSize)
		let updatedRowHeight = calculateRowHeight()
		if tableView.rowHeight != updatedRowHeight {
			tableView.rowHeight = updatedRowHeight
			tableView.reloadData()
		}
	}

	// MARK: - API
	
	func markAllAsRead() {

		guard let undoManager = undoManager, let markAllReadCommand = MarkAllReadCommand(initialArticles: articles, undoManager: undoManager) else {
			return
		}
		markAllReadCommand.perform()
	}
	
	// MARK: - Actions

	private func pushUndoableCommand(_ undoableCommand: UndoableCommand) {

		undoableCommands += [undoableCommand]
	}

	private func clearUndoableCommands() {

		// When the timeline is reloaded based on a different sidebar selection,
		// undoable commands should be dropped — otherwise things like
		// Redo Mark All as Read are ambiguous. (Do they apply to the previous articles
		// or to the current articles?)

		guard let undoManager = undoManager else {
			return
		}
		undoableCommands.forEach { undoManager.removeAllActions(withTarget: $0) }
		undoableCommands = [UndoableCommand]()
	}

	@objc func openArticleInBrowser(_ sender: AnyObject) {
		
		if let link = oneSelectedArticle?.preferredLink {
			Browser.open(link)
		}
	}
	
	@IBAction func toggleStatusOfSelectedArticles(_ sender: AnyObject) {
	
		guard !selectedArticles.isEmpty else {
			return
		}
		let articles = selectedArticles
		let status = articles.first!.status
		let markAsRead = !status.read
		
		markArticles(Set(articles), statusKey: .read, flag: markAsRead)
	}
	
	@IBAction func markSelectedArticlesAsRead(_ sender: AnyObject) {
		
		markArticles(Set(selectedArticles), statusKey: .read, flag: true)
	}
	
	@IBAction func markSelectedArticlesAsUnread(_ sender: AnyObject) {
		
		markArticles(Set(selectedArticles), statusKey: .read, flag: false)
	}
	
	// MARK: - Navigation
	
	func goToNextUnread() {
		
		guard let ix = indexOfNextUnreadArticle() else {
			return
		}
		tableView.rs_selectRow(ix)
		tableView.scrollTo(row: ix)
//		tableView.rs_selectRowAndScrollToVisible(ix)
	}
	
	func canGoToNextUnread() -> Bool {
		
		guard let _ = indexOfNextUnreadArticle() else {
			return false
		}
		return true
	}
	
	func canMarkAllAsRead() -> Bool {
		
		for article in articles {
			if !article.status.read {
				return true
			}
		}
		
		return false
	}
	
	func indexOfNextUnreadArticle() -> Int? {
		
		if articles.isEmpty {
			return nil
		}
		
		var ix = tableView.selectedRow
		while(true) {
			
			ix = ix + 1
			if ix >= articles.count {
				break
			}
			let article = articleAtRow(ix)!
			if !article.status.read {
				return ix
			}
		}
	
		return nil
	}
	
	// MARK: - Notifications

	@objc func sidebarSelectionDidChange(_ note: Notification) {

		let sidebarView = note.appInfo?.view

		if sidebarView?.window === tableView.window {
			representedObjects = note.appInfo?.objects
		}
	}
	
	@objc func statusesDidChange(_ note: Notification) {

		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		reloadCellsForArticleIDs(articles.articleIDs())
	}

	func fontSizeInDefaultsDidChange() {

		TimelineCellData.emptyCache()
		RSSingleLineRenderer.emptyCache()
		RSMultiLineRenderer.emptyCache()
		
		let updatedFontSize = AppDefaults.shared.timelineFontSize
		if updatedFontSize != self.fontSize {
			self.fontSize = updatedFontSize
		}
	}

	// MARK: - KeyboardDelegate
	
	func handleKeydownEvent(_ event: NSEvent, sender: AnyObject) -> Bool {
		
		guard !event.rs_keyIsModified() else {
			return false
		}
		
		guard let ch = event.rs_unmodifiedCharacterString() else {
			return false
		}

		let hasSelectedArticle = hasAtLeastOneSelectedArticle
		var keyHandled = false
		
		var shouldOpenInBrowser = false
		
		switch(ch) {
			
		case "\n":
			shouldOpenInBrowser = true
			keyHandled = true
		case "\r":
			shouldOpenInBrowser = true
			keyHandled = true
		
		case "r":
			markSelectedArticlesAsRead(sender)
			keyHandled = true
			
		case "u":
			markSelectedArticlesAsUnread(sender)
			keyHandled = true
			
		default:
			keyHandled = false
		}
		
		if !keyHandled {
			let chUnichar = event.rs_unmodifiedCharacter()
			
			switch(chUnichar) {
				
			case keypadEnter:
				shouldOpenInBrowser = true
				keyHandled = true
				
			default:
				keyHandled = false
			}
		}
	
		if shouldOpenInBrowser && hasSelectedArticle {
			openArticleInBrowser(self)
		}
		
		return keyHandled
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

		let indexes = indexesForArticleIDs(articleIDs)
		tableView.reloadData(forRowIndexes: indexes, columnIndexes: NSIndexSet(index: 0) as IndexSet)
	}
	
	// MARK: - Articles

	private func indexesForArticleIDs(_ articleIDs: Set<String>) -> IndexSet {
		
		var indexes = IndexSet()
		
		articleIDs.forEach { (articleID) in
			let oneIndex = rowForArticleID(articleID)
			if oneIndex != NSNotFound {
				indexes.insert(oneIndex)
			}
		}
		
		return indexes
	}
	
	private func articlesForIndexes(_ indexes: IndexSet) -> Set<Article> {
		
		return Set(indexes.flatMap{ (oneIndex) -> Article? in
			return articleAtRow(oneIndex)
		})
	}
	
	private func articleAtRow(_ row: Int) -> Article? {

		if row < 0 || row == NSNotFound || row > articles.count - 1 {
			return nil
		}
		return articles[row]
	}

	private func rowForArticle(_ article: Article) -> Int {

		return rowForArticleID(article.articleID)
	}

	private func rowForArticleID(_ articleID: String) -> Int {
		
		if let index = articles.index(where: { $0.articleID == articleID }) {
			return index
		}
		
		return NSNotFound
	}
	
	func selectedArticle() -> Article? {

		return articleAtRow(tableView.selectedRow)
	}

	// MARK: Sorting Articles

	private func articleComparator(_ article1: Article, article2: Article) -> Bool {

		return article1.logicalDatePublished > article2.logicalDatePublished
	}

	private func articlesSortedByDate(_ articles: Set<Article>) -> [Article] {
		
		return Array(articles).sorted(by: articleComparator)
	}
	
	// MARK: Fetching Articles

	private func emptyTheTimeline() {
		
		if !articles.isEmpty {
			articles = [Article]()
		}
	}
	
	private func fetchArticles() {

		guard let representedObjects = representedObjects else {
			emptyTheTimeline()
			return
		}
		
		var fetchedArticles = Set<Article>()
		
		for object in representedObjects {
			
			if let feed = object as? Feed {
				fetchedArticles.formUnion(feed.fetchArticles())
			}
			else if let folder = object as? Folder {
				fetchedArticles.formUnion(folder.fetchArticles())
			}
		}
		
		let sortedArticles = articlesSortedByDate(fetchedArticles)
		if articles != sortedArticles {
			articles = sortedArticles
		}
	}
	
	// MARK: - Cell Configuring

	private func calculateRowHeight() -> CGFloat {

		let longTitle = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?"
		let prototypeID = "prototype"
		let status = ArticleStatus(articleID: prototypeID, read: false, starred: false, userDeleted: false, dateArrived: Date())
		let prototypeArticle = Article(accountID: prototypeID, articleID: prototypeID, feedID: prototypeID, uniqueID: prototypeID, title: longTitle, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: nil, dateModified: nil, authors: nil, tags: nil, attachments: nil, status: status)
		
		let prototypeCellData = TimelineCellData(article: prototypeArticle, appearance: cellAppearance, showFeedName: false)
		let height = timelineCellHeight(100, cellData: prototypeCellData, appearance: cellAppearance)
		return height
	}

	private func configureTimelineCell(_ cell: TimelineTableCellView, article: Article) {
		
		cell.objectValue = article
		cell.cellData = TimelineCellData(article: article, appearance: cellAppearance, showFeedName: showFeedNames)
	}
	
	private func makeTimelineCellEmpty(_ cell: TimelineTableCellView) {
		
		cell.objectValue = nil
		cell.cellData = emptyCellData
	}
	
	// MARK: - NSTableViewDataSource

	func numberOfRows(in tableView: NSTableView) -> Int {

		return articles.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {

		return articleAtRow(row)
	}

	// MARK: - NSTableViewDelegate

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {

		let rowView: TimelineTableRowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineRow"), owner: self) as! TimelineTableRowView
		rowView.cellAppearance = cellAppearance
		return rowView
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

		let cell: TimelineTableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineCell"), owner: self) as! TimelineTableCellView
		cell.cellAppearance = cellAppearance
		
		if let article = articleAtRow(row) {
			configureTimelineCell(cell, article: article)
		}
		else {
			makeTimelineCellEmpty(cell)
		}

		return cell
	}

	private func postTimelineSelectionDidChangeNotification(_ selectedArticle: Article?) {

		let appInfo = AppInfo()
		if let article = selectedArticle {
			appInfo.article = article
		}
		appInfo.view = tableView

		NotificationCenter.default.post(name: .TimelineSelectionDidChange, object: self, userInfo: appInfo.userInfo)
	}

	func tableViewSelectionDidChange(_ notification: Notification) {

		tableView.redrawGrid()
		
		let selectedRow = tableView.selectedRow
		
		if selectedRow < 0 || selectedRow == NSNotFound || tableView.numberOfSelectedRows != 1 {
			postTimelineSelectionDidChangeNotification(nil)
			return
		}

		if let selectedArticle = articleAtRow(selectedRow) {
			if (!selectedArticle.status.read) {
				markArticles(Set([selectedArticle]), statusKey: .read, flag: true)
			}
			postTimelineSelectionDidChangeNotification(selectedArticle)
		}
		else {
			postTimelineSelectionDidChangeNotification(nil)
		}
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
}

private extension TimelineViewController {
	
	var hasAtLeastOneSelectedArticle: Bool {
		get {
			return self.tableView.selectedRow != -1
		}
	}
}

// MARK: - NSTableView extension

private extension NSTableView {
	
	func scrollTo(row: Int) {
		
		guard let scrollView = self.enclosingScrollView else {
			return
		}
		let documentVisibleRect = scrollView.documentVisibleRect
		
		let r = rect(ofRow: row)
		if NSContainsRect(documentVisibleRect, r) {
			return
		}
		
		let rMidY = NSMidY(r)
		var scrollPoint = NSZeroPoint;
		let extraHeight = 150
		scrollPoint.y = floor(rMidY - (documentVisibleRect.size.height / 2.0)) + CGFloat(extraHeight)
		scrollPoint.y = max(scrollPoint.y, 0)

		let maxScrollPointY = frame.size.height - documentVisibleRect.size.height
		scrollPoint.y = min(maxScrollPointY, scrollPoint.y)
		
		let clipView = scrollView.contentView
		
		let rClipView = NSMakeRect(scrollPoint.x, scrollPoint.y, NSWidth(clipView.bounds), NSHeight(clipView.bounds))
		
		clipView.animator().bounds = rClipView
	}
	
	func visibleRowViews() -> [TimelineTableRowView]? {
		
		guard let scrollView = self.enclosingScrollView, numberOfRows > 0 else {
			return nil
		}
		
		let range = rows(in: scrollView.documentVisibleRect)
		let ixMax = numberOfRows - 1
		let ixStart = min(range.location, ixMax)
		let ixEnd = min(((range.location + range.length) - 1), ixMax)
		
		var visibleRows = [TimelineTableRowView]()
		
		for ixRow in ixStart...ixEnd {
			if let oneRowView = rowView(atRow: ixRow, makeIfNecessary: false) as? TimelineTableRowView {
				visibleRows += [oneRowView]
			}
		}
		
		return visibleRows.isEmpty ? nil : visibleRows
	}
		
	func redrawGrid() {
		
		visibleRowViews()?.forEach { $0.invalidateGridRect() }
	}
}

