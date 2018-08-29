//
//  DockBadge.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/5/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

@objc final class DockBadge: NSObject {

	weak var appDelegate: AppDelegate?

	func update() {

		CoalescingQueue.standard.add(self, #selector(updateBadge))
	}

	@objc func updateBadge() {

		let unreadCount = appDelegate?.unreadCount ?? 0
		let label = unreadCount > 0 ? "\(unreadCount)" : ""
		NSApplication.shared.dockTile.badgeLabel = label
	}
}
