//
//  SidebarModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

protocol SidebarModelDelegate: class {
	func unreadCount(for: Feed) -> Int
}

class SidebarModel: ObservableObject {
	
	weak var delegate: SidebarModelDelegate?
	
	@Published var sidebarItems = [SidebarItem]()
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidInitialize(_:)), name: .UnreadCountDidInitialize, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)
	}
	
	// MARK: API
	
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
			
			for webFeed in sort(account.topLevelWebFeeds) {
				accountItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
			}
			
			for folder in sort(account.folders ?? Set<Folder>()) {
				var folderItem = SidebarItem(folder, unreadCount: delegate.unreadCount(for: folder))
				for webFeed in sort(folder.topLevelWebFeeds) {
					folderItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
				}
				accountItem.addChild(folderItem)
			}

			items.append(accountItem)
		}
		
		sidebarItems = items
	}
	
}

// MARK: Private

private extension SidebarModel {
	
	func sort(_ folders: Set<Folder>) -> [Folder] {
		return folders.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
	}

	func sort(_ feeds: Set<WebFeed>) -> [Feed] {
		return feeds.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
	}
	
	// MARK: Notifications
	
	@objc func unreadCountDidInitialize(_ notification: Notification) {
		guard notification.object is AccountManager else {
			return
		}
		rebuildSidebarItems()
	}
	
	@objc func containerChildrenDidChange(_ notification: Notification) {
		rebuildSidebarItems()
	}
	
	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildSidebarItems()
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		rebuildSidebarItems()
	}
	
	@objc func accountStateDidChange(_ note: Notification) {
		rebuildSidebarItems()
	}
	
	@objc func userDidAddAccount(_ note: Notification) {
		rebuildSidebarItems()
	}
	
	@objc func userDidDeleteAccount(_ note: Notification) {
		rebuildSidebarItems()
	}
	
}
