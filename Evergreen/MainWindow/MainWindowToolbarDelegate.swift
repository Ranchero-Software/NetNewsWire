//
//  MainWindowToolbarDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

extension NSToolbarItem.Identifier {
	static let Share = NSToolbarItem.Identifier("share")
}

@objc final class MainWindowToolbarDelegate: NSObject, NSToolbarDelegate {

	func toolbarWillAddItem(_ notification: Notification) {

		// The share button should send its action on mouse down, not mouse up.

		guard let item = notification.userInfo?["item"] as? NSToolbarItem else {
			return
		}
		guard item.itemIdentifier == .Share, let button = item.view as? NSButton else {
			return
		}

		button.sendAction(on: .leftMouseDown)
	}
}
