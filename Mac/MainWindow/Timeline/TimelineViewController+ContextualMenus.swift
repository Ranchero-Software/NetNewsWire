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

	var shareMenu: NSMenu? {
		return shareMenu(for: selectedArticles)
	}
	
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
		markArticles(articles, read: true, directlyMarked: true)
	}

	@objc func markArticlesUnreadFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else { return }
		markArticles(articles, read: false, directlyMarked: true)
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
		markArticles(articles, starred: true, directlyMarked: true)
	}

	@objc func markArticlesUnstarredFromContextualMenu(_ sender: Any?) {
		guard let articles = articles(from: sender) else {
			return
		}
		markArticles(articles, starred: false, directlyMarked: true)
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
		
		guard let undoManager = undoManager,
			  let markReadCommand = MarkStatusCommand(initialArticles: feedArticles,
													  markingRead: true,
													  directlyMarked: false,
													  undoManager: undoManager) else {
			return
		}
		
		runCommand(markReadCommand)
	}
	
	@objc func openInBrowserFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let urlStrings = menuItem.representedObject as? [String] else {
			return
		}

		Browser.open(urlStrings, fromWindow: self.view.window, invertPreference: NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false)
	}
	
	@objc func copyURLFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let urlStrings = menuItem.representedObject as? [String?] else {
			return
		}

		URLPasteboardWriter.write(urlStrings: urlStrings, alertingIn: self.view.window)
	}

	@objc func performShareServiceFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let sharingCommandInfo = menuItem.representedObject as? SharingCommandInfo else {
			return
		}
		sharingCommandInfo.perform()
	}
}


private extension TimelineViewController {

	func markArticles(_ articles: [Article], read: Bool, directlyMarked: Bool) {
		markArticles(articles, statusKey: .read, flag: read, directlyMarked: directlyMarked)
	}

	func markArticles(_ articles: [Article], starred: Bool, directlyMarked: Bool) {
		markArticles(articles, statusKey: .starred, flag: starred, directlyMarked: directlyMarked)
	}

	func markArticles(_ articles: [Article], statusKey: ArticleStatus.Key, flag: Bool, directlyMarked: Bool) {
		guard let undoManager = undoManager,
				let markStatusCommand = MarkStatusCommand(initialArticles: articles,
														  statusKey: statusKey,
														  flag: flag,
														  directlyMarked: directlyMarked,
														  undoManager: undoManager) else {
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

		let links = articles.map { $0.preferredLink }
		let compactLinks = links.compactMap { $0 }

		if compactLinks.count > 0 {
			menu.addSeparatorIfNeeded()
			menu.addItem(openInBrowserMenuItem(compactLinks))
			menu.addItem(openInBrowserReversedMenuItem(compactLinks))

			menu.addSeparatorIfNeeded()
			menu.addItem(copyArticleURLsMenuItem(links))

			if let externalLink = articles.first?.externalLink, externalLink != links.first {
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

		let menu = NSMenu(title: NSLocalizedString("button.title.share", comment: "Share menu name"))
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

		return menuItem(NSLocalizedString("button.title.mark-as-read", comment: "Mark as Read"), #selector(markArticlesReadFromContextualMenu(_:)), articles)
	}

	func markUnreadMenuItem(_ articles: [Article]) -> NSMenuItem {

		return menuItem(NSLocalizedString("button.title.mark-as-unread", comment: "Mark as Unread"), #selector(markArticlesUnreadFromContextualMenu(_:)), articles)
	}

	func markStarredMenuItem(_ articles: [Article]) -> NSMenuItem {

		return menuItem(NSLocalizedString("button.title.mark-as-starred", comment: "Mark as Starred"), #selector(markArticlesStarredFromContextualMenu(_:)), articles)
	}

	func markUnstarredMenuItem(_ articles: [Article]) -> NSMenuItem {

		return menuItem(NSLocalizedString("button.title.mark-as-unstarred", comment: "Mark as Unstarred"), #selector(markArticlesUnstarredFromContextualMenu(_:)), articles)
	}

	func markAboveReadMenuItem(_ articles: [Article]) -> NSMenuItem {
		return menuItem(NSLocalizedString("button.title-mark-above-as-read.titlecase", comment: "Mark Above as Read"),  #selector(markAboveArticlesReadFromContextualMenu(_:)), articles)
	}
	
	func markBelowReadMenuItem(_ articles: [Article]) -> NSMenuItem {
		return menuItem(NSLocalizedString("button.title-mark-below-as-read.titlecase", comment: "Mark Below as Read"),  #selector(markBelowArticlesReadFromContextualMenu(_:)), articles)
	}

	func selectFeedInSidebarMenuItem(_ feed: WebFeed) -> NSMenuItem {
		let localizedMenuText = NSLocalizedString("button.title.select-in-sidebar.%@", comment: "Select “%@” in Sidebar")
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

		let localizedMenuText = NSLocalizedString("button.title.mark-all-as-read.%@", comment: "Mark All as Read in “%@”")
		let menuText = NSString.localizedStringWithFormat(localizedMenuText as NSString, feed.nameForDisplay) as String
		
		return menuItem(menuText, #selector(markAllInFeedAsRead(_:)), articles)
	}
	
	func openInBrowserMenuItem(_ urlStrings: [String]) -> NSMenuItem {
		return menuItem(NSLocalizedString("button.title.open-in-browser", comment: "Open in Browser"), #selector(openInBrowserFromContextualMenu(_:)), urlStrings)
	}

	func openInBrowserReversedMenuItem(_ urlStrings: [String]) -> NSMenuItem {
		let item = menuItem(Browser.titleForOpenInBrowserInverted, #selector(openInBrowserFromContextualMenu(_:)), urlStrings)
		item.keyEquivalentModifierMask = .shift
		item.isAlternate = true
		return item;
	}
	
	func copyArticleURLsMenuItem(_ urlStrings: [String?]) -> NSMenuItem {
		let format = NSLocalizedString("button.title.copy-article-urls.%ld", comment: "Copy Article URL or Copy Article URLs (if more than one)")
		let title = String.localizedStringWithFormat(format, urlStrings.count)
		return menuItem(title, #selector(copyURLFromContextualMenu(_:)), urlStrings)
	}
	
	func copyExternalURLMenuItem(_ urlString: String) -> NSMenuItem {
		return menuItem(NSLocalizedString("button.title.copy-external-url", comment: "Copy External URL"), #selector(copyURLFromContextualMenu(_:)), urlString)
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
