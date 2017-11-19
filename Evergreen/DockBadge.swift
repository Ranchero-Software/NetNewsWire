//
//  DockBadge.swift
//  Evergreen
//
//  Created by Brent Simmons on 10/5/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

@objc final class DockBadge: NSObject {

	weak var appDelegate: AppDelegate?

	func update() {

		performSelectorCoalesced(#selector(updateBadge), with: nil, delay: 0.01)
	}

	@objc dynamic func updateBadge() {

		guard let appDelegate = appDelegate else {
			return
		}

		let unreadCount = appDelegate.unreadCount
		let label = unreadCount > 0 ? "\(unreadCount)" : ""
		NSApplication.shared.dockTile.badgeLabel = label
	}
}
