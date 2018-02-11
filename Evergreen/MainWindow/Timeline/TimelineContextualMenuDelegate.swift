//
//  TimelineContextualMenuDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 2/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

@objc final class TimelineContextualMenuDelegate: NSObject, NSMenuDelegate {

	@IBOutlet weak var timelineViewController: TimelineViewController?

	public func menuNeedsUpdate(_ menu: NSMenu) {

		guard let timelineViewController = timelineViewController else {
			return
		}

		menu.removeAllItems()

		guard let contextualMenu = timelineViewController.contextualMenuForClickedRows() else {
			return
		}

		menu.takeItems(from: contextualMenu)
	}
}


