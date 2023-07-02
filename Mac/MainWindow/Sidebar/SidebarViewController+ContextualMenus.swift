//
//  SidebarViewController+ContextualMenus.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import Account
import RSCore
import UserNotifications

extension Notification.Name {
	public static let DidUpdateFeedPreferencesFromContextMenu = Notification.Name(rawValue: "DidUpdateFeedPreferencesFromContextMenu")
}

extension SidebarViewController {

	func menu(for objects: [Any]?) -> NSMenu? {

		guard let objects = objects, objects.count > 0 else {
			return menuForNoSelection()
		}

		if objects.count > 1 {
			return menuForMultipleObjects(objects)
		}

		let object = objects.first!

		switch object {
		case is WebFeed:
			return menuForWebFeed(object as! WebFeed)
		case is Folder:
			return menuForFolder(object as! Folder)
		case is PseudoFeed:
			return menuForSmartFeed(object as! PseudoFeed)
		default:
			return nil
		}
	}
}

// MARK: Contextual Menu Actions

extension SidebarViewController {

	@objc func openHomePageFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		Browser.open(urlString, inBackground: false)
	}

	@objc func copyURLFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		URLPasteboardWriter.write(urlString: urlString, to: NSPasteboard.general)
	}

	@objc func markObjectsReadFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let objects = menuItem.representedObject as? [Any] else {
			return
		}
		
		var markableArticles = unreadArticles(for: objects)
		if let directlyMarkedAsUnreadArticles = delegate?.directlyMarkedAsUnreadArticles {
			markableArticles = markableArticles.subtracting(directlyMarkedAsUnreadArticles)
		}

		guard let undoManager = undoManager,
				let markReadCommand = MarkStatusCommand(initialArticles: markableArticles,
														markingRead: true,
														directlyMarked: false,
														undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}


	@objc func markObjectsReadOlderThanOneDayFromContextualMenu(_ sender: Any?) {
		return markObjectsReadBetweenDatesFromContextualMenu(before: Calendar.current.date(byAdding: .day, value: -1, to: Date()), after: nil, sender: sender)
	}

	@objc func markObjectsReadOlderThanTwoDaysFromContextualMenu(_ sender: Any?) {
		return markObjectsReadBetweenDatesFromContextualMenu(before: Calendar.current.date(byAdding: .day, value: -2, to: Date()), after: nil, sender: sender)
	}

	@objc func markObjectsReadOlderThanThreeDaysFromContextualMenu(_ sender: Any?) {
		return markObjectsReadBetweenDatesFromContextualMenu(before: Calendar.current.date(byAdding: .day, value: -3, to: Date()), after: nil, sender: sender)
	}

	@objc func markObjectsReadOlderThanOneWeekFromContextualMenu(_ sender: Any?) {
		return markObjectsReadBetweenDatesFromContextualMenu(before: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()), after: nil, sender: sender)
	}

	@objc func markObjectsReadOlderThanTwoWeeksFromContextualMenu(_ sender: Any?) {
		return markObjectsReadBetweenDatesFromContextualMenu(before: Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()), after: nil, sender: sender)
	}

	@objc func markObjectsReadOlderThanOneMonthFromContextualMenu(_ sender: Any?) {
		return markObjectsReadBetweenDatesFromContextualMenu(before: Calendar.current.date(byAdding: .month, value: -1, to: Date()), after: nil, sender: sender)
	}

	@objc func markObjectsReadOlderThanOneYearFromContextualMenu(_ sender: Any?) {
		return markObjectsReadBetweenDatesFromContextualMenu(before: Calendar.current.date(byAdding: .year, value: -1, to: Date()), after: nil, sender: sender)
	}

	func markObjectsReadBetweenDatesFromContextualMenu(before: Date?, after: Date?, sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let objects = menuItem.representedObject as? [Any] else {
			return
		}

		var markableArticles = unreadArticlesBetween(for: objects, before: before, after: after)
		if let directlyMarkedAsUnreadArticles = delegate?.directlyMarkedAsUnreadArticles {
			markableArticles = markableArticles.subtracting(directlyMarkedAsUnreadArticles)
		}

		guard let undoManager = undoManager,
				let markReadCommand = MarkStatusCommand(initialArticles: markableArticles,
														markingRead: true,
														directlyMarked: false,
														undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}

	@objc func deleteFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let objects = menuItem.representedObject as? [AnyObject] else {
			return
		}
		
		let nodes = objects.compactMap { treeController.nodeInTreeRepresentingObject($0) }

		let alert = SidebarDeleteItemsAlert.build(nodes)
		alert.beginSheetModal(for: view.window!) { [weak self] result in
			if result == NSApplication.ModalResponse.alertFirstButtonReturn {
				self?.deleteNodes(nodes)
			}
		}
	}

	@objc func renameFromContextualMenu(_ sender: Any?) {

		guard let window = view.window, let menuItem = sender as? NSMenuItem, let object = menuItem.representedObject as? DisplayNameProvider, object is WebFeed || object is Folder else {
			return
		}

		renameWindowController = RenameWindowController(originalTitle: object.nameForDisplay, representedObject: object, delegate: self)
		guard let renameSheet = renameWindowController?.window else {
			return
		}
		window.beginSheet(renameSheet)
	}
	
	@objc func toggleNotificationsFromContextMenu(_ sender: Any?) {
		guard let item = sender as? NSMenuItem,
			  let feed = item.representedObject as? WebFeed else {
			return
		}
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			if settings.authorizationStatus == .denied {
				self.showNotificationsNotEnabledAlert()
			} else if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					if feed.isNotifyAboutNewArticles == nil { feed.isNotifyAboutNewArticles = false }
					feed.isNotifyAboutNewArticles?.toggle()
					NotificationCenter.default.post(Notification(name: .DidUpdateFeedPreferencesFromContextMenu))
				}
			} else {
				UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
					if granted {
						DispatchQueue.main.async {
							if feed.isNotifyAboutNewArticles == nil { feed.isNotifyAboutNewArticles = false }
							feed.isNotifyAboutNewArticles?.toggle()
							NotificationCenter.default.post(Notification(name: .DidUpdateFeedPreferencesFromContextMenu))
							NSApplication.shared.registerForRemoteNotifications()
						}
					} else {
						self.showNotificationsNotEnabledAlert()
					}
				}
			}
		}
	}
	
	@objc func toggleArticleExtractorFromContextMenu(_ sender: Any?) {
		guard let item = sender as? NSMenuItem,
			  let feed = item.representedObject as? WebFeed else {
			return
		}
		if feed.isArticleExtractorAlwaysOn == nil { feed.isArticleExtractorAlwaysOn = false }
		feed.isArticleExtractorAlwaysOn?.toggle()
		NotificationCenter.default.post(Notification(name: .DidUpdateFeedPreferencesFromContextMenu))
	}
	
	func showNotificationsNotEnabledAlert() {
		DispatchQueue.main.async {
			let alert = NSAlert()
			alert.messageText = NSLocalizedString("alert.title.notifications-not-enabled", comment: "Notifications are not enabled.")
			alert.informativeText = NSLocalizedString("alert.message.enable-notifications-in-settings", comment: "You can enable NetNewsWire notifications in System Settings.")
			alert.addButton(withTitle: NSLocalizedString("button.title.open-settings", comment: "Open Settings"))
			alert.addButton(withTitle: NSLocalizedString("button.title.dismiss", comment: "Dismiss"))
			let userChoice = alert.runModal()
			if userChoice == .alertFirstButtonReturn {
				let config = NSWorkspace.OpenConfiguration()
				config.activates = true
				// If System Preferences is already open, and no delay is provided here, then it appears in the foreground and immediately disappears.
				DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.2, execute: {
					NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!, configuration: config)
				})
			}
		}
	}
	
}

extension SidebarViewController: RenameWindowControllerDelegate {

	func renameWindowController(_ windowController: RenameWindowController, didRenameObject object: Any, withNewName name: String) {

		if let feed = object as? WebFeed {
			feed.rename(to: name) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		} else if let folder = object as? Folder {
			folder.rename(to: name) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		}
	}
}

// MARK: Build Contextual Menus

private extension SidebarViewController {

	func menuForNoSelection() -> NSMenu {

		let menu = NSMenu(title: "")

		menu.addItem(withTitle: NSLocalizedString("button.title.new-feed", comment: "New Feed"), action: #selector(AppDelegate.showAddFeedWindow(_:)), keyEquivalent: "")
		menu.addItem(withTitle: NSLocalizedString("button.title.new-folder", comment: "New Folder"), action: #selector(AppDelegate.showAddFolderWindow(_:)), keyEquivalent: "")

		return menu
	}

	func menuForWebFeed(_ webFeed: WebFeed) -> NSMenu? {

		let menu = NSMenu(title: "")

		if webFeed.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([webFeed]))
			let catchUpMenuItem = NSMenuItem(title: NSLocalizedString("button.title.mark-as-read-older-than", comment: "Mark as Read Older Than"), action: nil, keyEquivalent: "")
			let catchUpSubMenu = catchUpSubMenu([webFeed])

			menu.addItem(catchUpMenuItem)
			menu.setSubmenu(catchUpSubMenu, for: catchUpMenuItem)

			menu.addItem(NSMenuItem.separator())
		}

		if let homePageURL = webFeed.homePageURL, let _ = URL(string: homePageURL) {
			let item = menuItem(NSLocalizedString("button.title.open-home-page", comment: "Open Home Page"), #selector(openHomePageFromContextualMenu(_:)), homePageURL.decodedURLString ?? homePageURL)
			menu.addItem(item)
			menu.addItem(NSMenuItem.separator())
		}

		let copyFeedURLItem = menuItem(NSLocalizedString("button.title.copy-feed-url", comment: "Copy Feed URL"), #selector(copyURLFromContextualMenu(_:)), webFeed.url.decodedURLString ?? webFeed.url)
		menu.addItem(copyFeedURLItem)

		if let homePageURL = webFeed.homePageURL {
			let item = menuItem(NSLocalizedString("button.title.copy-home-page-url", comment: "Copy Home Page URL"), #selector(copyURLFromContextualMenu(_:)), homePageURL.decodedURLString ?? homePageURL)
			menu.addItem(item)
		}
		menu.addItem(NSMenuItem.separator())
		
		let notificationText = webFeed.notificationDisplayName.capitalized
		
		let notificationMenuItem = menuItem(notificationText, #selector(toggleNotificationsFromContextMenu(_:)), webFeed)
		if webFeed.isNotifyAboutNewArticles == nil || webFeed.isNotifyAboutNewArticles! == false {
			notificationMenuItem.state = .off
		} else {
			notificationMenuItem.state = .on
		}
		menu.addItem(notificationMenuItem)
		
		let articleExtractorText = NSLocalizedString("button.title.always-use-reader-view", comment: "Always Use Reader View")
		let articleExtractorMenuItem = menuItem(articleExtractorText, #selector(toggleArticleExtractorFromContextMenu(_:)), webFeed)
		
		if webFeed.isArticleExtractorAlwaysOn == nil || webFeed.isArticleExtractorAlwaysOn! == false {
			articleExtractorMenuItem.state = .off
		} else {
			articleExtractorMenuItem.state = .on
		}
		menu.addItem(articleExtractorMenuItem)		
		
		menu.addItem(NSMenuItem.separator())
		
		menu.addItem(renameMenuItem(webFeed))
		menu.addItem(deleteMenuItem([webFeed]))

		return menu
	}

	func menuForFolder(_ folder: Folder) -> NSMenu? {

		let menu = NSMenu(title: "")

		if folder.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([folder]))
			let catchUpMenuItem = NSMenuItem(title: NSLocalizedString("button.title.mark-as-read-older-than", comment: "Mark as Read Older Than"), action: nil, keyEquivalent: "")
			let catchUpSubMenu = catchUpSubMenu([folder])

			menu.addItem(catchUpMenuItem)
			menu.setSubmenu(catchUpSubMenu, for: catchUpMenuItem)
			menu.addItem(NSMenuItem.separator())
		}

		menu.addItem(renameMenuItem(folder))
		menu.addItem(deleteMenuItem([folder]))

		return menu.numberOfItems > 0 ? menu : nil
	}

	func menuForSmartFeed(_ smartFeed: PseudoFeed) -> NSMenu? {

		let menu = NSMenu(title: "")

		if smartFeed.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([smartFeed]))

			// Doesn't make sense to mark articles newer than a day with catch up with first option being older than a day
			if let maybeSmartFeed = smartFeed as? SmartFeed {
				if maybeSmartFeed.delegate is TodayFeedDelegate {
					return menu
				}
			}

			let catchUpMenuItem = NSMenuItem(title: NSLocalizedString("button.title.mark-as-read-older-than", comment: "Mark as Read Older Than"), action: nil, keyEquivalent: "")
			let catchUpSubMenu = catchUpSubMenu([smartFeed])
			menu.addItem(catchUpMenuItem)
			menu.setSubmenu(catchUpSubMenu, for: catchUpMenuItem)
		}
		return menu.numberOfItems > 0 ? menu : nil
	}

	func menuForMultipleObjects(_ objects: [Any]) -> NSMenu? {

		let menu = NSMenu(title: "")

		if anyObjectInArrayHasNonZeroUnreadCount(objects) {
			menu.addItem(markAllReadMenuItem(objects))
			let catchUpMenuItem = NSMenuItem(title: NSLocalizedString("button.title.mark-as-read-older-than", comment: "Mark as Read Older Than"), action: nil, keyEquivalent: "")
			let catchUpSubMenu = catchUpSubMenu(objects)

			menu.addItem(catchUpMenuItem)
			menu.setSubmenu(catchUpSubMenu, for: catchUpMenuItem)
		}

		if allObjectsAreFeedsAndOrFolders(objects) {
			menu.addSeparatorIfNeeded()
			menu.addItem(deleteMenuItem(objects))
		}

		return menu.numberOfItems > 0 ? menu : nil
	}

	func markAllReadMenuItem(_ objects: [Any]) -> NSMenuItem {

		return menuItem(NSLocalizedString("button.title.mark-all-as-read.titlecase", comment: "Mark All as Read"), #selector(markObjectsReadFromContextualMenu(_:)), objects)
	}

	func catchUpSubMenu(_ objects: [Any]) -> NSMenu {
		let menu = NSMenu(title: NSLocalizedString("menu.title.catch-up-to-articles", comment: "Catch up to articles older than..."))

		menu.addItem(menuItem(NSLocalizedString("button.title.1-day", comment: "1 day"), #selector(markObjectsReadOlderThanOneDayFromContextualMenu(_:)), objects))
		menu.addItem(menuItem(NSLocalizedString("button.title.2-days", comment: "2 days"), #selector(markObjectsReadOlderThanTwoDaysFromContextualMenu(_:)), objects))
		menu.addItem(menuItem(NSLocalizedString("button.title.3-days", comment: "3 days"), #selector(markObjectsReadOlderThanThreeDaysFromContextualMenu(_:)), objects))
		menu.addItem(menuItem(NSLocalizedString("button.title.1-week", comment: "1 week"), #selector(markObjectsReadOlderThanOneWeekFromContextualMenu(_:)), objects))
		menu.addItem(menuItem(NSLocalizedString("button.title.2-weeks", comment: "2 weeks"), #selector(markObjectsReadOlderThanTwoWeeksFromContextualMenu(_:)), objects))
		menu.addItem(menuItem(NSLocalizedString("button.title.1-month", comment: "1 month"), #selector(markObjectsReadOlderThanOneMonthFromContextualMenu(_:)), objects))
		menu.addItem(menuItem(NSLocalizedString("button.title.1-year", comment: "1 year"), #selector(markObjectsReadOlderThanOneYearFromContextualMenu(_:)), objects))

		return menu
	}

	func deleteMenuItem(_ objects: [Any]) -> NSMenuItem {

		return menuItem(NSLocalizedString("button.title.delete", comment: "Delete"), #selector(deleteFromContextualMenu(_:)), objects)
	}

	func renameMenuItem(_ object: Any) -> NSMenuItem {

		return menuItem(NSLocalizedString("button.title.rename", comment: "Rename"), #selector(renameFromContextualMenu(_:)), object)
	}

	func anyObjectInArrayHasNonZeroUnreadCount(_ objects: [Any]) -> Bool {

		for object in objects {
			if let unreadCountProvider = object as? UnreadCountProvider {
				if unreadCountProvider.unreadCount > 0 {
					return true
				}
			}
		}
		return false
	}

	func allObjectsAreFeedsAndOrFolders(_ objects: [Any]) -> Bool {

		for object in objects {
			if !objectIsFeedOrFolder(object) {
				return false
			}
		}
		return true
	}

	func objectIsFeedOrFolder(_ object: Any) -> Bool {

		return object is WebFeed || object is Folder
	}

	func menuItem(_ title: String, _ action: Selector, _ representedObject: Any) -> NSMenuItem {

		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.representedObject = representedObject
		item.target = self
		return item
	}

	func unreadArticles(for objects: [Any]) -> Set<Article> {

		var articles = Set<Article>()
		for object in objects {
			if let articleFetcher = object as? ArticleFetcher {
				if let unreadArticles = try? articleFetcher.fetchUnreadArticles() {
					articles.formUnion(unreadArticles)
				}
			}
		}
		return articles
	}

	func unreadArticlesBetween(for objects: [Any], before: Date?, after: Date?) -> Set<Article> {

		var articles = Set<Article>()
		for object in objects {
			if let articleFetcher = object as? ArticleFetcher {
				if let unreadArticles = try? articleFetcher.fetchUnreadArticlesBetween(before: before, after: after) {
					articles.formUnion(unreadArticles)
				}
			}
		}
		return articles
	}
}

