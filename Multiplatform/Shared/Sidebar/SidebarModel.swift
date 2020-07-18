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
	
	private var cancellables = Set<AnyCancellable>()

	private let rebuildSidebarItemsQueue = CoalescingQueue(name: "Rebuild The Sidebar Items", interval: 0.5)

	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	init() {
		NotificationCenter.default.publisher(for: .UnreadCountDidInitialize)
			.filter { $0.object is AccountManager }
			.sink {  [weak self] note in
				guard let self = self else { return	}
				self.rebuildSidebarItems(isReadFiltered: self.isReadFiltered)
			}.store(in: &cancellables)

		NotificationCenter.default.publisher(for: .UnreadCountDidChange)
			.filter { _ in AccountManager.shared.isUnreadCountsInitialized }
			.sink {  [weak self] _ in
				self?.queueRebuildSidebarItems()
			}.store(in: &cancellables)

		let chidrenDidChangePublisher = NotificationCenter.default.publisher(for: .ChildrenDidChange)
		let batchUpdateDidPerformPublisher = NotificationCenter.default.publisher(for: .BatchUpdateDidPerform)
		let displayNameDidChangePublisher = NotificationCenter.default.publisher(for: .DisplayNameDidChange)
		let accountStateDidChangePublisher = NotificationCenter.default.publisher(for: .AccountStateDidChange)
		let userDidAddAccountPublisher = NotificationCenter.default.publisher(for: .UserDidAddAccount)
		let userDidDeleteAccountPublisher = NotificationCenter.default.publisher(for: .UserDidDeleteAccount)

		let sidebarRebuildPublishers = chidrenDidChangePublisher.merge(with: batchUpdateDidPerformPublisher,
																	   displayNameDidChangePublisher,
																	   accountStateDidChangePublisher,
																	   userDidAddAccountPublisher,
																	   userDidDeleteAccountPublisher)

		sidebarRebuildPublishers.sink {  [weak self] _ in
			guard let self = self else { return	}
			self.rebuildSidebarItems(isReadFiltered: self.isReadFiltered)
		}.store(in: &cancellables)


		// TODO: This should be rewritten to use Combine correctly
		$selectedFeedIdentifiers.sink { [weak self] feedIDs in
			guard let self = self else { return }
			self.selectedFeeds = feedIDs.compactMap { self.findFeed($0) }
		}.store(in: &cancellables)
		
		// TODO: This should be rewritten to use Combine correctly
		$selectedFeedIdentifier.sink { [weak self] feedID in
			guard let self = self else { return }
			if let feedID = feedID, let feed = self.findFeed(feedID) {
				self.selectedFeeds = [feed]
			}
		}.store(in: &cancellables)

		$isReadFiltered.sink { [weak self] filter in
			self?.rebuildSidebarItems(isReadFiltered: filter)
		}.store(in: &cancellables)
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
	
}
