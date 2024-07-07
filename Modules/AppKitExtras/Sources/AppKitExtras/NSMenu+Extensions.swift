//
//  NSMenu+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 2/9/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSMenu {

	func takeItems(from menu: NSMenu) {

		// The passed-in menu gets all its items removed.

		let items = menu.items
		menu.removeAllItems()
		for menuItem in items {
			addItem(menuItem)
		}
	}

	/// Add a separator if there are multiple menu items and the last one is not a separator.
	func addSeparatorIfNeeded() {
		if items.count > 0 && !items.last!.isSeparatorItem {
			addItem(NSMenuItem.separator())
		}
	}
}
#endif
