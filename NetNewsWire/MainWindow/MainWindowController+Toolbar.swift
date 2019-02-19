//
//  MainWindowController+Toolbar.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

extension NSToolbarItem.Identifier {
	static let Share = NSToolbarItem.Identifier("share")
	static let Search = NSToolbarItem.Identifier("search")
}

extension MainWindowController: NSToolbarDelegate {

	func toolbarWillAddItem(_ notification: Notification) {
		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}

		if item.itemIdentifier == .Share, let button = item.view as? NSButton {
			// The share button should send its action on mouse down, not mouse up.
			button.sendAction(on: .leftMouseDown)
		}

		if item.itemIdentifier == .Search, let searchField = item.view as? NSSearchField {
			searchField.delegate = self
		}
	}

	func toolbarDidRemoveItem(_ notification: Notification) {
		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}

		if item.itemIdentifier == .Search, let searchField = item.view as? NSSearchField {
			searchField.delegate = nil
		}
	}
}
