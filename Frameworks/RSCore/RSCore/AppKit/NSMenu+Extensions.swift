//
//  NSMenu+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 2/9/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import AppKit

public extension NSMenu {

	public func takeItems(from menu: NSMenu) {

		// The passed-in menu gets all its items removed.

		let items = menu.items
		menu.removeAllItems()
		for menuItem in items {
			addItem(menuItem)
		}
	}
}
