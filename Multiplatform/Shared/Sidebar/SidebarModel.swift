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

		for account in AccountManager.shared.sortedActiveAccounts {
			var accountItem = SidebarItem(account)
			
			for webFeed in account.topLevelWebFeeds {
				accountItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
			}
			
			for folder in account.folders ?? Set<Folder>() {
				var folderItem = SidebarItem(folder, unreadCount: delegate.unreadCount(for: folder))
				for webFeed in folder.topLevelWebFeeds {
					folderItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
				}
				accountItem.addChild(folderItem)
			}

			items.append(accountItem)
		}
		
		sidebarItems = items
	}
	
}
