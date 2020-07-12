//
//  SidebarModel.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Combine
import RSCore
import Account

protocol SidebarModelDelegate: class {
	func unreadCount(for: Feed) -> Int
}

class SidebarModel: ObservableObject, UndoableCommandRunner {
	
	weak var delegate: SidebarModelDelegate?
	
	@Published var sidebarItems = [SidebarItem]()
	@Published var selectedFeedIdentifiers = Set<FeedIdentifier>()
	@Published var selectedFeedIdentifier: FeedIdentifier? = .none
	@Published var selectedFeeds = [Feed]()
	@Published var isReadFiltered = false
	
	private var selectedFeedIdentifiersCancellable: AnyCancellable?
	private var selectedFeedIdentifierCancellable: AnyCancellable?
	private var selectedReadFilteredCancellable: AnyCancellable?

	private let rebuildSidebarItemsQueue = CoalescingQueue(name: "Rebuild The Sidebar Items", interval: 0.5)

	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidInitialize(_:)), name: .UnreadCountDidInitialize, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountStateDidChange(_:)), name: .AccountStateDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)
		
		// TODO: This should be rewritten to use Combine correctly
		selectedFeedIdentifiersCancellable = $selectedFeedIdentifiers.sink { [weak self] feedIDs in
			guard let self = self else { return }
			self.selectedFeeds = feedIDs.compactMap { self.findFeed($0) }
		}
		
		// TODO: This should be rewritten to use Combine correctly
		selectedFeedIdentifierCancellable = $selectedFeedIdentifier.sink { [weak self] feedID in
			guard let self = self else { return }
			if let feedID = feedID, let feed = self.findFeed(feedID) {
				self.selectedFeeds = [feed]
			}
		}

		selectedReadFilteredCancellable = $isReadFiltered.sink { [weak self] filter in
			guard let self = self else { return }
			self.rebuildSidebarItems(isReadFiltered: filter)
		}
	}
	
	// MARK: API
	
	/// Rebuilds the sidebar items to cause the sidebar to rebuild itself
	func rebuildSidebarItems() {
		rebuildSidebarItemsWithCurrentValues()
	}

}

// MARK: Private

private extension SidebarModel {
	
	func findFeed(_ feedID: FeedIdentifier) -> Feed? {
		switch feedID {
		case .smartFeed:
			return SmartFeedsController.shared.find(by: feedID)
		default:
			return AccountManager.shared.existingFeed(with: feedID)
		}
	}
	
	func sort(_ folders: Set<Folder>) -> [Folder] {
		return folders.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
	}

	func sort(_ feeds: Set<WebFeed>) -> [Feed] {
		return feeds.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
	}
	
	func queueRebuildSidebarItems() {
		rebuildSidebarItemsQueue.add(self, #selector(rebuildSidebarItemsWithCurrentValues))
	}
	
	@objc func rebuildSidebarItemsWithCurrentValues() {
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}
	
	func rebuildSidebarItems(isReadFiltered: Bool) {
		guard let delegate = delegate else { return }
		var items = [SidebarItem]()
		
		var smartFeedControllerItem = SidebarItem(SmartFeedsController.shared)
		for feed in SmartFeedsController.shared.smartFeeds {
// It looks like SwiftUI loses its mind when the last element in a section is removed.  Don't filter
// the smartfeeds yet or we crash about everytime because Starred is almost always filtered
//			if !isReadFiltered || feed.unreadCount > 0 {
				smartFeedControllerItem.addChild(SidebarItem(feed, unreadCount: delegate.unreadCount(for: feed)))
//			}
		}
		items.append(smartFeedControllerItem)

		for account in AccountManager.shared.sortedActiveAccounts {
			var accountItem = SidebarItem(account)
			
			for webFeed in sort(account.topLevelWebFeeds) {
				if !isReadFiltered || webFeed.unreadCount > 0 {
					accountItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
				}
			}
			
			for folder in sort(account.folders ?? Set<Folder>()) {
				if !isReadFiltered || folder.unreadCount > 0 {
					var folderItem = SidebarItem(folder, unreadCount: delegate.unreadCount(for: folder))
					for webFeed in sort(folder.topLevelWebFeeds) {
						if !isReadFiltered || webFeed.unreadCount > 0 {
							folderItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
						}
					}
					accountItem.addChild(folderItem)
				}
			}

			items.append(accountItem)
		}
		
		sidebarItems = items
	}
	
	// MARK: Notifications
	
	@objc func unreadCountDidInitialize(_ notification: Notification) {
		guard notification.object is AccountManager else {
			return
		}
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		// We will handle the filtering of unread feeds in unreadCountDidInitialize after they have all be calculated
		guard AccountManager.shared.isUnreadCountsInitialized else {
			return
		}
		queueRebuildSidebarItems()
	}
	
	@objc func containerChildrenDidChange(_ notification: Notification) {
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}
	
	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}
	
	@objc func accountStateDidChange(_ note: Notification) {
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}
	
	@objc func userDidAddAccount(_ note: Notification) {
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}
	
	@objc func userDidDeleteAccount(_ note: Notification) {
		rebuildSidebarItems(isReadFiltered: isReadFiltered)
	}
	
}
