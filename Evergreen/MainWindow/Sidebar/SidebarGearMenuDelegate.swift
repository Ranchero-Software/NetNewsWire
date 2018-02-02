//
//  SidebarGearMenuDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

@objc final class SidebarGearMenuDelegate: NSObject, NSMenuDelegate {

	@IBOutlet weak var sidebarViewController: SidebarViewController?

	public func menuNeedsUpdate(_ menu: NSMenu) {

		guard let sidebarViewController = sidebarViewController else {
			return
		}

		// Save the first item, since it’s the gear icon itself.
		guard let gearMenuItem = menu.item(at: 0) else {
			assertionFailure("Expected sidebar gear menu to have at least one item.")
			return
		}
		menu.removeAllItems()
		menu.addItem(gearMenuItem)

		guard let contextualMenu = sidebarViewController.contextualMenuForSelectedObjects() else {
			return
		}

		let items = contextualMenu.items
		contextualMenu.removeAllItems()
		for menuItem in items {
			menu.addItem(menuItem)
		}
	}
}
