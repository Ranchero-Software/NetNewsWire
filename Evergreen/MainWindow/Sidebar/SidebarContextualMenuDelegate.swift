//
//  SidebarContextualMenuDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/7/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

@objc final class SidebarContextualMenuDelegate: NSObject, NSMenuDelegate {

	@IBOutlet weak var sidebarViewController: SidebarViewController?

	public func menuNeedsUpdate(_ menu: NSMenu) {

		guard let sidebarViewController = sidebarViewController else {
			return
		}

		menu.removeAllItems()

		guard let contextualMenu = sidebarViewController.contextualMenuForClickedRows() else {
			return
		}

		menu.takeItems(from: contextualMenu)
	}
}

