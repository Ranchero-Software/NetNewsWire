//
//  TimelineViewController+ContextualMenus.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/9/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import Articles
import Account

extension TimelineViewController {

	func contextualMenuForClickedRows() -> NSMenu? {

		let row = tableView.clickedRow
		guard row != -1, let article = articles.articleAtRow(row) else {
			return nil
		}

		if selectedArticles.contains(article) {
			// If the clickedRow is part of the selected rows, then do a contextual menu for all the selected rows.
			return menu(for: selectedArticles)
		}
		return menu(for: [article])
	}
}

// MARK: Contextual Menu Actions

extension TimelineViewController {

	@objc func markArticlesReadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markArticles(articles, read: true)
	}

	@objc func markArticlesUnreadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markArticles(articles, read: false)
	}

	@objc func markAboveArticlesReadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markAboveArticlesRead(articles)
	}

	@objc func markBelowArticlesReadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markBelowArticlesRead(articles)
	}

	@objc func markArticlesStarredFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markArticles(articles, starred: true)
	}

	@objc func markArticlesUnstarredFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else {
			return
		}
		markArticles(articles, starred: false)
	}

	@objc func selectFeedInSidebarFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let webFeed = menuItem.representedObject as? WebFeed else {
			return
		}
		delegate?.timelineRequestedWebFeedSelection(self, webFeed: webFeed)
	}
	
	@objc func markAllInFeedAsRead(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let feedArticles = menuItem.representedObject as? ArticleArray else {
			return
		}
		
		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: feedArticles, markingRead: true, undoManager: undoManager) else {
			return
		}
		
		runCommand(markReadCommand)
	}
	
	@objc func openInBrowserFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		Browser.open(urlString, inBackground: false)
	}
	
	@objc func copyURLFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		URLPasteboardWriter.write(urlString: urlString, to: .general)
	}

	@objc func performShareServiceFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let sharingCommandInfo = menuItem.representedObject as? SharingCommandInfo else {
			return
		}
		sharingCommandInfo.perform()
	}
}


private extension TimelineViewController {

	func markArticles(_ articles: [Article], read: Bool) {
		markArticles(articles, statusKey: .read, flag: read)
	}

	func markArticles(_ articles: [Article], starred: Bool) {
		markArticles(articles, statusKey: .starred, flag: starred)
	}

	func markArticles(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool) {
		guard let undoManager = undoManager, let markStatusCommand = MarkStatusCommand(initialArticles: articles, statusKey: statusKey, flag: flag, undoManager: undoManager) else {
			return
		}

		runCommand(markStatusCommand)
	}

	func unreadArticles(from articles: [Article]) -> [Article]? {
		let filteredArticles = articles.filter { !$0.status.read }
		return filteredArticles.isEmpty ? nil : filteredArticles
	}

	func readArticles(from articles: [Article]) -> [Article]? {
		let filteredArticles = articles.filter { $0.status.read }
		return filteredArticles.isEmpty ? nil : filteredArticles
	}

	func articles(from sender: Any?) -> [Article]? {
		return (sender as? NSMenuItem)?.representedObject as? [Article]
	}

	func menu(for articles: [Article]) -> NSMenu? {
		let menu = NSMenu(title: "")

		if articles.anyArticleIsUnread() {
			menu.addItem(markReadMenuItem(articles))
		}
		if articles.anyArticleIsReadAndCanMarkUnread() {
			menu.addItem(markUnreadMenuItem(articles))
		}
		if articles.anyArticleIsUnstarred() {
			menu.addItem(markStarredMenuItem(articles))
		}
		if articles.anyArticleIsStarred() {
			menu.addItem(markUnstarredMenuItem(articles))
		}
		if let first = articles.first, self.articles.articlesAbove(article: first).canMarkAllAsRead() {
			menu.addItem(markAboveReadMenuItem(articles))
		}
		if let last = articles.last, self.articles.articlesBelow(article: last).canMarkAllAsRead() {
			menu.addItem(markBelowReadMenuItem(articles))
		}

		menu.addSeparatorIfNeeded()
		
		if articles.count == 1, let feed = articles.first!.webFeed {
			if !(representedObjects?.contains(where: { $0 as? WebFeed == feed }) ?? false) {
				menu.addItem(selectFeedInSidebarMenuItem(feed))
			}
			if let markAllMenuItem = markAllAsReadMenuItem(feed) {
				menu.addItem(markAllMenuItem)
			}
		}
		
		if articles.count == 1, let link = articles.first!.preferredLink {
			menu.addSeparatorIfNeeded()
			menu.addItem(openInBrowserMenuItem(link))
			menu.addSeparatorIfNeeded()
			menu.addItem(copyArticleURLMenuItem(link))
			
			if let externalLink = articles.first?.externalURL, externalLink != link {
				menu.addItem(copyExternalURLMenuItem(externalLink))
			}
		}

		if let sharingMenu = shareMenu(for: articles) {
			menu.addSeparatorIfNeeded()
			let menuItem = NSMenuItem(title: sharingMenu.title, action: nil, keyEquivalent: "")
			menuItem.submenu = sharingMenu
			menu.addItem(menuItem)
		}

		return menu
	}

	func shareMenu(for articles: [Article]) -> NSMenu? {
		if articles.isEmpty {
			return nil
		}

		let sortedArticles = articles.sortedByDate(.orderedAscending)
		let items = sortedArticles.map { ArticlePasteboardWriter(article: $0) }
		let standardServices = NSSharingService.sharingServices(forItems: items)
		let customServices = SharingServicePickerDelegate.customSharingServices(for: items)
		let services = standardServices + customServices
		if services.isEmpty {
			return nil
		}

		let menu = NSMenu(title: NSLocalizedString("Share", comment: "Share menu name"))
		services.forEach { (service) in
			service.delegate = sharingServiceDelegate
			let menuItem = NSMenuItem(title: service.menuItemTitle, action: #selector(performShareServiceFromContextualMenu(_:)), keyEquivalent: "")
			menuItem.image = service.image
			let sharingCommandInfo = SharingCommandInfo(service: service, items: items)
			menuItem.representedObject = sharingCommandInfo
			menu.addItem(menuItem)
		}

		return menu
	}

	func markReadMenuItem(_ articles: [Article]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Mark as Read", comment: "Command"), #selector(markArticlesReadFromContextualMenu(_:)), articles)
	}

	func markUnreadMenuItem(_ articles: [Article]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Mark as Unread", comment: "Command"), #selector(markArticlesUnreadFromContextualMenu(_:)), articles)
	}

	func markStarredMenuItem(_ articles: [Article]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Mark as Starred", comment: "Command"), #selector(markArticlesStarredFromContextualMenu(_:)), articles)
	}

	func markUnstarredMenuItem(_ articles: [Article]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Mark as Unstarred", comment: "Command"), #selector(markArticlesUnstarredFromContextualMenu(_:)), articles)
	}

	func markAboveReadMenuItem(_ articles: [Article]) -> NSMenuItem {
		return menuItem(NSLocalizedString("Mark Above as Read", comment: "Command"),  #selector(markAboveArticlesReadFromContextualMenu(_:)), articles)
	}
	
	func markBelowReadMenuItem(_ articles: [Article]) -> NSMenuItem {
		return menuItem(NSLocalizedString("Mark Below as Read", comment: "Command"),  #selector(markBelowArticlesReadFromContextualMenu(_:)), articles)
	}

	func selectFeedInSidebarMenuItem(_ feed: WebFeed) -> NSMenuItem {
		let localizedMenuText = NSLocalizedString("Select “%@” in Sidebar", comment: "Command")
		let formattedMenuText = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay)
		return menuItem(formattedMenuText as String, #selector(selectFeedInSidebarFromContextualMenu(_:)), feed)
	}

	func markAllAsReadMenuItem(_ feed: WebFeed) -> NSMenuItem? {
		guard let articlesSet = try? feed.fetchArticles() else {
			return nil
		}
		let articles = Array(articlesSet)
		guard articles.canMarkAllAsRead() else {
			return nil
		}

		let localizedMenuText = NSLocalizedString("Mark All as Read in “%@”", comment: "Command")
		let menuText = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
		
		return menuItem(menuText, #selector(markAllInFeedAsRead(_:)), articles)
	}
	
	func openInBrowserMenuItem(_ urlString: String) -> NSMenuItem {

		return menuItem(NSLocalizedString("Open in Browser", comment: "Command"), #selector(openInBrowserFromContextualMenu(_:)), urlString)
	}
	
	func copyArticleURLMenuItem(_ urlString: String) -> NSMenuItem {
		return menuItem(NSLocalizedString("Copy Article URL", comment: "Command"), #selector(copyURLFromContextualMenu(_:)), urlString)
	}
	
	func copyExternalURLMenuItem(_ urlString: String) -> NSMenuItem {
		return menuItem(NSLocalizedString("Copy External URL", comment: "Command"), #selector(copyURLFromContextualMenu(_:)), urlString)
	}


	func menuItem(_ title: String, _ action: Selector, _ representedObject: Any) -> NSMenuItem {

		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.representedObject = representedObject
		item.target = self
		return item
	}
}

private final class SharingCommandInfo {

	let service: NSSharingService
	let items: [Any]

	init(service: NSSharingService, items: [Any]) {
		self.service = service
		self.items = items
	}

	func perform() {
		service.perform(withItems: items)
	}
}
