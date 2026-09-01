//
//  SidebarSortType.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/24/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

enum SidebarSortType: Int {
	case alphabetically = 0
	case byUnreadCount = 1
}

extension Notification.Name {
	static let SidebarSortTypeDidChange = Notification.Name("SidebarSortTypeDidChange")
}
