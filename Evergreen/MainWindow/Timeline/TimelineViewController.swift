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
import Data
import Account

class TimelineViewController: NSViewController, KeyboardDelegate, UndoableCommandRunner {

	@IBOutlet var tableView: TimelineTableView!

	var selectedArticles: [Article] {
		get {
			return Array(articles.articlesForIndexes(tableView.selectedRowIndexes))
		}
	}

	var undoableCommands = [UndoableCommand]()
	private var cellAppearance: TimelineCellAppearance!
	private var showFeedNames = false
	private var didRegisterForNotifications = false
	private let timelineFontSizeKVOKey = "values.{AppDefaults.Key.timelineFontSize}"

	private var articles = ArticleArray() {
		didSet {
			if articles != oldValue {
				clearUndoableCommands()
				tableView.reloadData()
			}
		}
	}

	private var fontSize: FontSize = AppDefaults.shared.timelineFontSize {
		didSet {
			fontSizeDidChange()
		}
	}

	private var representedObjects: [AnyObject]? {
		didSet {
			if !representedObjectArraysAreEqual(oldValue, representedObjects) {
				postTimelineSelectionDidChangeNotification(nil)
				fetchArticles()
				if articles.count > 0 {
					tableView.scrollRowToVisible(0)
				}
			}
		}
	}

	private var oneSelectedArticle: Article? {
		get {
			return selectedArticles.count == 1 ? selectedArticles.first : nil
		}
	}

	override func viewDidLoad() {

		cellAppearance = TimelineCellAppearance(theme: appDelegate.currentTheme, fontSize: fontSize)

		tableView.rowHeight = calculateRowHeight()
		tableView.target = self
		tableView.doubleAction = #selector(openArticleInBrowser(_:))
		tableView.keyboardDelegate = self
		tableView.setDraggingSourceOperationMask(.copy, forLocal: false)

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

		cellAppearance = TimelineCellAppearance(theme: appDelegate.currentTheme, fontSize: fontSize)
		let updatedRowHeight = calculateRowHeight()
		if tableView.rowHeight != updatedRowHeight {
			tableView.rowHeight = updatedRowHeight
			tableView.reloadData()
		}
	}

	// MARK: - API
	
	func markAllAsRead() {

		guard let undoManager = undoManager, let markReadCommand = MarkReadOrUnreadCommand(initialArticles: articles, markingRead: true, undoManager: undoManager) else {
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

		if markAsRead {
			markSelectedArticlesAsRead(sender)
		}
		else {
			markSelectedArticlesAsUnread(sender)
		}
	}
	
	@IBAction func markSelectedArticlesAsRead(_ sender: AnyObject?) {

		guard let undoManager = undoManager, let markReadCommand = MarkReadOrUnreadCommand(initialArticles: selectedArticles, markingRead: true, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}
	
	@IBAction func markSelectedArticlesAsUnread(_ sender: AnyObject) {
		
		guard let undoManager = undoManager, let markUnreadCommand = MarkReadOrUnreadCommand(initialArticles: selectedArticles, markingRead: false, undoManager: undoManager) else {
			return
		}
		runCommand(markUnreadCommand)
	}
	
	// MARK: - Navigation
	
	func goToNextUnread() {
		
		guard let ix = indexOfNextUnreadArticle() else {
			return
		}
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

		let indexes = articles.indexesForArticleIDs(articleIDs)
		tableView.reloadData(forRowIndexes: indexes, columnIndexes: NSIndexSet(index: 0) as IndexSet)
	}
	
	// MARK: - Cell Configuring

	private func calculateRowHeight() -> CGFloat {

		let longTitle = "But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who do not know how to pursue pleasure rationally encounter consequences that are extremely painful. Nor again is there anyone who loves or pursues or desires to obtain pain of itself, because it is pain, but because occasionally circumstances occur in which toil and pain can procure him some great pleasure. To take a trivial example, which of us ever undertakes laborious physical exercise, except to obtain some advantage from it? But who has any right to find fault with a man who chooses to enjoy a pleasure that has no annoying consequences, or one who avoids a pain that produces no resultant pleasure?"
		let prototypeID = "prototype"
		let status = ArticleStatus(articleID: prototypeID, read: false, starred: false, userDeleted: false, dateArrived: Date())
		let prototypeArticle = Article(accountID: prototypeID, articleID: prototypeID, feedID: prototypeID, uniqueID: prototypeID, title: longTitle, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, bannerImageURL: nil, datePublished: nil, dateModified: nil, authors: nil, tags: nil, attachments: nil, status: status)
		
		let prototypeCellData = TimelineCellData(article: prototypeArticle, appearance: cellAppearance, showFeedName: false, favicon: nil, avatar: nil, featuredImage: nil)
		let height = timelineCellHeight(100, cellData: prototypeCellData, appearance: cellAppearance)
		return height
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

	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {

		let rowView: TimelineTableRowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineRow"), owner: self) as! TimelineTableRowView
		rowView.cellAppearance = cellAppearance
		return rowView
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

		let cell: TimelineTableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "timelineCell"), owner: self) as! TimelineTableCellView
		cell.cellAppearance = cellAppearance

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

		let selectedRow = tableView.selectedRow
		if selectedRow < 0 || selectedRow == NSNotFound || tableView.numberOfSelectedRows != 1 {
			postTimelineSelectionDidChangeNotification(nil)
			return
		}

		if let selectedArticle = articles.articleAtRow(selectedRow) {
			if (!selectedArticle.status.read) {
				markArticles(Set([selectedArticle]), statusKey: .read, flag: true)
			}
			postTimelineSelectionDidChangeNotification(selectedArticle)
		}
		else {
			postTimelineSelectionDidChangeNotification(nil)
		}
	}

	private func postTimelineSelectionDidChangeNotification(_ selectedArticle: Article?) {

		let appInfo = AppInfo()
		if let article = selectedArticle {
			appInfo.article = article
		}
		appInfo.view = tableView

		NotificationCenter.default.post(name: .TimelineSelectionDidChange, object: self, userInfo: appInfo.userInfo)
	}

	private func configureTimelineCell(_ cell: TimelineTableCellView, article: Article) {

		cell.objectValue = article

		let favicon = faviconFor(article)
		let avatar = avatarFor(article)
		let featuredImage = featuredImageFor(article)

		cell.cellData = TimelineCellData(article: article, appearance: cellAppearance, showFeedName: showFeedNames, favicon: favicon, avatar: avatar, featuredImage: featuredImage)
	}

	private func faviconFor(_ article: Article) -> NSImage? {

		guard let feed = article.feed else {
			return nil
		}
		return appDelegate.faviconDownloader.favicon(for: feed)
	}

	private func avatarFor(_ article: Article) -> NSImage? {

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

		// TODO: make Feed know about its authors.
		// https://github.com/brentsimmons/Evergreen/issues/212

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
		cell.cellData = emptyCellData
	}
}

// MARK: - Private

private extension TimelineViewController {
	
	var hasAtLeastOneSelectedArticle: Bool {
		get {
			return tableView.selectedRow != -1
		}
	}

	func emptyTheTimeline() {

		if !articles.isEmpty {
			articles = [Article]()
		}
	}

	// MARK: Fetching Articles

	func fetchArticles() {

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

		let sortedArticles = Array(fetchedArticles).sortedByDate()
		if articles != sortedArticles {
			articles = sortedArticles
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

