//
//  TimelineViewController+ContextualMenus.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/9/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Data
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

		guard let articles = articles(from: sender) else {
			return
		}
		markArticles(articles, read: true)
	}

	@objc func markArticlesUnreadFromContextualMenu(_ sender: Any?) {

		guard let articles = articles(from: sender) else {
			return
		}
		markArticles(articles, read: false)
	}

	@objc func markArticlesStarredFromContextualMenu(_ sender: Any?) {

	}

	@objc func markArticlesUnstarredFromContextualMenu(_ sender: Any?) {

	}

	@objc func openInBrowserFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		Browser.open(urlString, inBackground: false)
	}
}


private extension TimelineViewController {

	func markArticles(_ articles: [Article], read: Bool) {

		guard let articlesToMark = read ? unreadArticles(from: articles) : readArticles(from: articles) else {
			return
		}
		guard let undoManager = undoManager, let markReadCommand = MarkReadOrUnreadCommand(initialArticles: Array(articlesToMark), markingRead: read, undoManager: undoManager) else {
			return
		}

		runCommand(markReadCommand)
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
		if articles.anyArticleIsRead() {
			menu.addItem(markUnreadMenuItem(articles))
		}
		if menu.items.count > 0 {
			menu.addItem(NSMenuItem.separator())
		}

//		if articles.anyArticleIsUnstarred() {
//			menu.addItem(markStarredMenuItem(articles))
//		}
//		if articles.anyArticleIsStarred() {
//			menu.addItem(markUnstarredMenuItem(articles))
//		}
		if menu.items.count > 0 && !menu.items.last!.isSeparatorItem {
			menu.addItem(NSMenuItem.separator())
		}

		if articles.count == 1, let link = articles.first!.preferredLink {
			menu.addItem(openInBrowserMenuItem(link))
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

	func openInBrowserMenuItem(_ urlString: String) -> NSMenuItem {

		return menuItem(NSLocalizedString("Open in Browser", comment: "Command"), #selector(openInBrowserFromContextualMenu(_:)), urlString)
	}

	func menuItem(_ title: String, _ action: Selector, _ representedObject: Any) -> NSMenuItem {

		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.representedObject = representedObject
		item.target = self
		return item
	}
}
