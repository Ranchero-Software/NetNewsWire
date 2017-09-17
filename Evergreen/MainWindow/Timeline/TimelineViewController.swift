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

let timelineFontSizeKVOKey = "values." + TimelineFontSizeKey

class TimelineViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, KeyboardDelegate {

	@IBOutlet var tableView: TimelineTableView!
	var didRegisterForNotifications = false
	var fontSize: FontSize = timelineFontSize() {
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
			return articlesForIndexes(tableView.selectedRowIndexes)
		}
	}

	private var oneSelectedArticle: Article? {
		get {
			return selectedArticles.count == 1 ? selectedArticles.first : nil
		}
	}

	override func viewDidLoad() {

		cellAppearance = TimelineCellAppearance(theme: currentTheme, fontSize: fontSize)
		tableView.rowHeight = calculateRowHeight()

		tableView.target = self
		tableView.doubleAction = #selector(openArticleInBrowser(_:))
		
		tableView.keyboardDelegate = self
		
		if !didRegisterForNotifications {

			NotificationCenter.default.addObserver(self, selector: #selector(sidebarSelectionDidChange(_:)), name: .SidebarSelectionDidChange, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(articleStatusesDidChange(_:)), name: .ArticleStatusesDidChange, object: nil)

			NSUserDefaultsController.shared.addObserver(self, forKeyPath:timelineFontSizeKVOKey, options: NSKeyValueObservingOptions(rawValue: 0), context: nil)

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

	// MARK: API
	
	func markAllAsRead() {
		
		if articles.isEmpty {
			return
		}
		
		let articlesSet = NSMutableSet()
		articlesSet.addObjects(from: articles)
		markArticles(articlesSet, statusKey: .read, flag: true)
		
		reloadCellsForArticles(articles)
	}
	
	// MARK: Actions
	
	@objc func openArticleInBrowser(_ sender: AnyObject) {
		
		if let link = oneSelectedArticle?.preferredLink {
			openInBrowser(link)
		}
	}
	
	@IBAction func toggleStatusOfSelectedArticles(_ sender: AnyObject) {
	
		guard !selectedArticles.isEmpty else {
			return
		}
		let articles = selectedArticles
		var markAsRead = true
		if articles.first!.status.read {
			markAsRead = false
		}
		
		markArticles(NSSet(array: articles), statusKey: .read, flag: markAsRead)
	}
	
	@IBAction func markSelectedArticlesAsRead(_ sender: AnyObject) {
		
		markArticles(NSSet(array: selectedArticles), statusKey: .read, flag: true)
	}
	
	@IBAction func markSelectedArticlesAsUnread(_ sender: AnyObject) {
		
		markArticles(NSSet(array: selectedArticles), statusKey: .read, flag: false)
	}
	
	// MARK: Navigation
	
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
		
		for oneArticle in articles {
			if !oneArticle.status.read {
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
	
	// MARK: Notifications

	@objc func sidebarSelectionDidChange(_ note: Notification) {

		let sidebarView = note.userInfo?[viewKey] as! NSView

		if sidebarView.window! === tableView.window {
			representedObjects = note.userInfo?[objectsKey] as? [AnyObject]
		}
	}
	
	@objc func articleStatusesDidChange(_ note: Notification) {
		
		guard let articles = note.userInfo?[articlesKey] as? NSSet else {
			return
		}
		
		reloadCellsForArticles(articles.allObjects as! [Article])
	}

	func fontSizeInDefaultsDidChange() {

		TimelineCellData.emptyCache()
		RSSingleLineRenderer.emptyCache()
		RSMultiLineRenderer.emptyCache()
		
		let updatedFontSize = timelineFontSize()
		if updatedFontSize != self.fontSize {
			self.fontSize = updatedFontSize
		}
	}

	// MARK: KeyboardDelegate
	
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

	// MARK: Reloading Data
	
	private func cellForRowView(_ rowView: NSView) -> NSView? {
		
		for oneView in rowView.subviews where oneView is TimelineTableCellView {
			return oneView
		}
		return nil
	}
	
	private func reloadCellsForArticles(_ articles: [Article]) {
		
		let indexes = indexesForArticles(articles)
		tableView.reloadData(forRowIndexes: indexes, columnIndexes: NSIndexSet(index: 0) as IndexSet)
	}
	
	// MARK: Articles

	private func indexesForArticles(_ articles: [Article]) -> IndexSet {
		
		var indexes = IndexSet()
		
		articles.forEach { (article) in
			let oneIndex = rowForArticle(article)
			if oneIndex != NSNotFound {
				indexes.insert(oneIndex)
			}
		}

		return indexes
	}
	
	private func articlesForIndexes(_ indexes: IndexSet) -> [Article] {
		
		return indexes.flatMap{ (oneIndex) -> Article? in
			return articleAtRow(oneIndex)
		}
	}
	
	private func articleAtRow(_ row: Int) -> Article? {

		if row < 0 || row == NSNotFound || row > articles.count - 1 {
			return nil
		}
		return articles[row]
	}

	private func rowForArticle(_ article: Article) -> Int {

		if let index = articles.index(where: { (oneArticle) -> Bool in
			return oneArticle === article
		}) {
			return index
		}
		
		return NSNotFound
	}

	func selectedArticle() -> Article? {

		return articleAtRow(tableView.selectedRow)
	}

	// MARK: Sorting Articles

	private func articleComparator(_ article1: Article, article2: Article) -> Bool {

		return article1.logicalDatePublished.compare(article2.logicalDatePublished) == .orderedDescending
	}

	// MARK: Fetching Articles

	private func fetchArticles() {

		guard let representedObjects = representedObjects else {
			if !articles.isEmpty {
				articles = [Article]()
			}
			return
		}
		
		var accountsDictionary = [String: [AnyObject]]()

		func addToAccountArray(accountID: String, object: AnyObject) {

			if let accountArray = accountsDictionary[accountID] {
				if !accountArray.contains(where: { $0 === object }) {
					accountsDictionary[accountID] = accountArray + [object]
				}
			}
			else {
				accountsDictionary[accountID] = [object]
			}
		}

		for oneObject in representedObjects {

			if let oneFeed = oneObject as? Feed {
				addToAccountArray(accountID: oneFeed.account.identifier, object: oneFeed)
			}
			else if let oneFolder = oneObject as? Folder, let accountID = oneFolder.account?.identifier {
				addToAccountArray(accountID: accountID, object: oneFolder)
			}
		}

		var fetchedArticles = [Article]()
		for (accountID, objects) in accountsDictionary {

			guard let oneAccount = AccountManager.sharedInstance.existingAccountWithIdentifier(accountID) else {
				continue
			}

			let oneFetchedArticles = oneAccount.fetchArticles(for: objects)
			for oneFetchedArticle in oneFetchedArticles {
				if !fetchedArticles.contains(where: { $0 === oneFetchedArticle }) {
					fetchedArticles += [oneFetchedArticle]
				}
			}
		}

		fetchedArticles.sort(by: articleComparator)

		if !articleArraysAreIdentical(array1: articles, array2: fetchedArticles) {
			articles = fetchedArticles
		}			
	}
	
	// MARK: Cell Configuring

	private func calculateRowHeight() -> CGFloat {

		let prototypeArticle = LocalArticle(account: AccountManager.sharedInstance.localAccount, feedID: "prototype", articleID: "prototype")
		prototypeArticle.title = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?"
		
		let prototypeArticleStatus = LocalArticleStatus(articleID: "prototype", read: false, starred: false, userDeleted: false, dateArrived: Date())
		prototypeArticle.status = prototypeArticleStatus
		
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
	
	// MARK: NSTableViewDataSource

	func numberOfRows(in tableView: NSTableView) -> Int {

		return articles.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {

		return articleAtRow(row)
	}

	// MARK: NSTableViewDelegate

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {

		let rowView: TimelineTableRowView = tableView.make(withIdentifier: "timelineRow", owner: self) as! TimelineTableRowView
		rowView.cellAppearance = cellAppearance
		return rowView
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

		let cell: TimelineTableCellView = tableView.make(withIdentifier: "timelineCell", owner: self) as! TimelineTableCellView
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

		var userInfo = [String: AnyObject]()
		if let article = selectedArticle {
			userInfo[articleKey] = article
		}
		userInfo[viewKey] = self.tableView

		NotificationCenter.default.post(name: .TimelineSelectionDidChange, object: self, userInfo: userInfo)
	}

	func tableViewSelectionDidChange(_ notification: Notification) {

		tableView.redrawGrid()
		
		let selectedRow = tableView.selectedRow
		
		if selectedRow < 0 || selectedRow == NSNotFound || tableView.numberOfSelectedRows != 1 {
			postTimelineSelectionDidChangeNotification(nil)
			return
		}

		if let selectedArticle = articleAtRow(selectedRow) {
			let articleSet = NSSet(array: [selectedArticle])
			if (!selectedArticle.status.read) {
				markArticles(articleSet, statusKey: .read, flag: true)
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
