//
//  SidebarModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

protocol SidebarModelDelegate: class {
	func sidebarSelectionDidChange(_: SidebarModel, feeds: [Feed]?)
	func unreadCount(for: Feed) -> Int
}

class SidebarModel: ObservableObject {
	
	weak var delegate: SidebarModelDelegate?
	
	@Published var sidebarItems = [SidebarItem]()
	
	func rebuildSidebarItems() {
		guard let delegate = delegate else { return }
		var items = [SidebarItem]()
		
		var smartFeedControllerItem = SidebarItem(SmartFeedsController.shared)
		for feed in SmartFeedsController.shared.smartFeeds {
			smartFeedControllerItem.addChild(SidebarItem(feed, unreadCount: delegate.unreadCount(for: feed)))
		}
		items.append(smartFeedControllerItem)

		sidebarItems = items
	}
	
}
