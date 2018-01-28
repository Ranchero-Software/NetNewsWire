//
//  MainWindowController+ContextualMenus.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Data
import Account

extension MainWindowController {

	func menu(for objects: [Any]?) -> NSMenu? {

		guard let objects = objects, objects.count > 0 else {
			return nil
		}

		if objects.count == 1 {
			if let feed = objects.first as? Feed {
				return menuForFeed(feed)
			}
			if let folder = objects.first as? Folder {
				return menuForFolder(folder)
			}
			return nil
		}

		return menuForMultipleObjects(objects)
	}
}

// MARK: Contextual Menu Actions

extension MainWindowController {

	@objc func openHomePageFromContextualMenu(_ sender: Any?) {

	}

	@objc func copyStringFromContextualMenu(_ sender: Any?) {

	}

	@objc func markObjectsReadFromContextualMenu(_ sender: Any?) {

	}

	@objc func deleteFromContextualMenu(_ sender: Any?) {

	}

	@objc func renameFromContextualMenu(_ sender: Any?) {

	}
}

// MARK: Build Contextual Menus

private extension MainWindowController {

	func menuForFeed(_ feed: Feed) -> NSMenu? {

		let menu = NSMenu(title: "")

		if feed.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([feed]))
			menu.addItem(NSMenuItem.separator())
		}

		if let homePageURL = feed.homePageURL, let _ = URL(string: homePageURL) {
			let item = menuItem(NSLocalizedString("Open Home Page", comment: "Command"), #selector(openHomePageFromContextualMenu(_:)), homePageURL)
			menu.addItem(item)
			menu.addItem(NSMenuItem.separator())
		}

		let copyFeedURLItem = menuItem(NSLocalizedString("Copy Feed URL", comment: "Command"), #selector(copyStringFromContextualMenu(_:)), feed.url)
		menu.addItem(copyFeedURLItem)

		if let homePageURL = feed.homePageURL {
			let item = menuItem(NSLocalizedString("Copy Home Page URL", comment: "Command"), #selector(copyStringFromContextualMenu(_:)), homePageURL)
			menu.addItem(item)
		}
		menu.addItem(NSMenuItem.separator())

		menu.addItem(renameMenuItem(feed))
		menu.addItem(deleteMenuItem([feed]))

		return menu
	}

	func menuForFolder(_ folder: Folder) -> NSMenu? {

		let menu = NSMenu(title: "")

		if folder.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([folder]))
			menu.addItem(NSMenuItem.separator())
		}

		return menu.numberOfItems > 0 ? menu : nil
	}

	func menuForMultipleObjects(_ objects: [Any]) -> NSMenu? {

		let menu = NSMenu(title: "")

		if anyObjectInArrayHasNonZeroUnreadCount(objects) {
			menu.addItem(markAllReadMenuItem(objects))
			menu.addItem(NSMenuItem.separator())
		}


		return menu.numberOfItems > 0 ? menu : nil
	}

	func markAllReadMenuItem(_ objects: [Any]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Mark All as Read", comment: "Command"), #selector(markObjectsReadFromContextualMenu(_:)), objects)
	}

	func deleteMenuItem(_ objects: [Any]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Delete", comment: "Command"), #selector(deleteFromContextualMenu(_:)), objects)
	}

	func renameMenuItem(_ object: Any) -> NSMenuItem {

		return menuItem(NSLocalizedString("Rename", comment: "Command"), #selector(renameFromContextualMenu(_:)), object)
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

	func menuItem(_ title: String, _ action: Selector, _ representedObject: Any) -> NSMenuItem {

		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.representedObject = representedObject
		item.target = self
		return item
	}
}

