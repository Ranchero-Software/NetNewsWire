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

	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	init() {
		subscribeToRebuildSidebarItemsEvents()
		subscribeToSelectedFeedChanges()
	}

	// MARK: API

	func goToNextUnread() {
		guard let startFeed = selectedFeeds.first ?? sidebarItems.first?.children.first?.feed else { return }
		
		if !goToNextUnread(startingAt: startFeed) {
			if let firstFeed = sidebarItems.first?.children.first?.feed {
				goToNextUnread(startingAt: firstFeed)
			}
		}
	}
	
}

// MARK: Private

private extension SidebarModel {
	
	// MARK: Subscriptions
	
	func subscribeToRebuildSidebarItemsEvents() {
		let chidrenDidChangePublisher = NotificationCenter.default.publisher(for: .ChildrenDidChange)
		let batchUpdateDidPerformPublisher = NotificationCenter.default.publisher(for: .BatchUpdateDidPerform)
		let displayNameDidChangePublisher = NotificationCenter.default.publisher(for: .DisplayNameDidChange)
		let accountStateDidChangePublisher = NotificationCenter.default.publisher(for: .AccountStateDidChange)
		let userDidAddAccountPublisher = NotificationCenter.default.publisher(for: .UserDidAddAccount)
		let userDidDeleteAccountPublisher = NotificationCenter.default.publisher(for: .UserDidDeleteAccount)
		let unreadCountDidInitializePublisher = NotificationCenter.default.publisher(for: .UnreadCountDidInitialize)
		let unreadCountDidChangePublisher = NotificationCenter.default.publisher(for: .UnreadCountDidChange)

		let sidebarRebuildPublishers = chidrenDidChangePublisher.merge(with: batchUpdateDidPerformPublisher,
																	   displayNameDidChangePublisher,
																	   accountStateDidChangePublisher,
																	   userDidAddAccountPublisher,
																	   userDidDeleteAccountPublisher,
																	   unreadCountDidInitializePublisher,
																	   unreadCountDidChangePublisher)

		sidebarRebuildPublishers
			.combineLatest($isReadFiltered)
			.debounce(for: .milliseconds(500), scheduler: RunLoop.main)
			.sink {  [weak self] _, readFilter in
				self?.rebuildSidebarItems(isReadFiltered: readFilter)
		}.store(in: &cancellables)
	}
	
	func subscribeToSelectedFeedChanges() {
		$selectedFeedIdentifiers.map { [weak self] feedIDs in
			feedIDs.compactMap { self?.findFeed($0) }
		}
		.assign(to: $selectedFeeds)
		
		$selectedFeedIdentifier.compactMap { [weak self] feedID in
			if let feedID = feedID, let feed = self?.findFeed(feedID) {
				return [feed]
			} else {
				return nil
			}
		}
		.assign(to: $selectedFeeds)
	}
	
	// MARK: Sidebar Building
	
	func sort(_ folders: Set<Folder>) -> [Folder] {
		return folders.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
	}

	func sort(_ feeds: Set<WebFeed>) -> [Feed] {
		return feeds.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
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
	
	// MARK:
	
	func findFeed(_ feedID: FeedIdentifier) -> Feed? {
		switch feedID {
		case .smartFeed:
			return SmartFeedsController.shared.find(by: feedID)
		default:
			return AccountManager.shared.existingFeed(with: feedID)
		}
	}
	
	@discardableResult
	func goToNextUnread(startingAt: Feed) -> Bool {

		var foundStartFeed = false
		var nextSidebarItem: SidebarItem? = nil
		for section in sidebarItems {
			if nextSidebarItem == nil  {
				section.visit { sidebarItem in
					if !foundStartFeed && sidebarItem.feed?.feedID == startingAt.feedID {
						foundStartFeed = true
						return false
					}
					if foundStartFeed && sidebarItem.unreadCount > 0 {
						nextSidebarItem = sidebarItem
						return true
					}
					return false
				}
			}
		}

		if let nextFeedID = nextSidebarItem?.feed?.feedID {
			select(nextFeedID)
			return true
		}
		
		return false
	}

	func select(_ feedID: FeedIdentifier) {
		selectedFeedIdentifiers = Set([feedID])
		selectedFeedIdentifier = feedID
	}
	
}
