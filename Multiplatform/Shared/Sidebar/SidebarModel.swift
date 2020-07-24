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
import Articles

protocol SidebarModelDelegate: class {
	func unreadCount(for: Feed) -> Int
}

class SidebarModel: ObservableObject, UndoableCommandRunner {
	
	@Published var selectedFeedIdentifiers = Set<FeedIdentifier>()
	@Published var selectedFeedIdentifier: FeedIdentifier? = .none
	@Published var isReadFiltered = false
	
	weak var delegate: SidebarModelDelegate?

	var sidebarItemsPublisher: AnyPublisher<[SidebarItem], Never>?
	var selectedFeedsPublisher: AnyPublisher<[Feed], Never>?
	
	var selectNextUnread = PassthroughSubject<Bool, Never>()
	var markAllAsReadInFeed = PassthroughSubject<Feed, Never>()
	var markAllAsReadInAccount = PassthroughSubject<Feed, Never>()

	private var cancellables = Set<AnyCancellable>()

	var undoManager: UndoManager?
	var undoableCommands = [UndoableCommand]()

	init() {
		subscribeToSelectedFeedChanges()
		subscribeToRebuildSidebarItemsEvents()
		subscribeToNextUnread()
		subscribeToMarkAllAsReadInFeed()
	}
	
}

// MARK: Side Context Menu Actions

private extension SidebarModel {
	
	func subscribeToMarkAllAsReadInFeed() {
		guard let selectedFeedsPublisher = selectedFeedsPublisher else { return }

		markAllAsReadInFeed
			.withLatestFrom(selectedFeedsPublisher, resultSelector: { givenFeed, selectedFeeds -> [Feed] in
				if selectedFeeds.contains(where: { $0.feedID == givenFeed.feedID }) {
					return selectedFeeds
				} else {
					return [givenFeed]
				}
			})
			.map { feeds in
				var articles = [Article]()
				for feed in feeds {
					articles.append(contentsOf: (try? feed.fetchArticles()) ?? Set<Article>())
				}
				return articles
			}
			.sink { [weak self] allArticles in
				self?.markAllAsRead(allArticles)
			}
			.store(in: &cancellables)
	}
	
	func markAllAsRead(account: Account) {
		var articles = Set<Article>()
		for feed in account.flattenedWebFeeds() {
			let unreadArticles = try! feed.fetchUnreadArticles()
			articles.formUnion(unreadArticles)
		}
		markAllAsRead(Array(articles))
	}
	
	
	/// Marks provided artices as read.
	/// - Parameter articles: An array of `Article`s.
	/// - Warning: An `UndoManager` is created here as the `Environment`'s undo manager appears to be `nil`.
	private func markAllAsRead(_ articles: [Article]) {
		guard let undoManager = undoManager ?? UndoManager(),
			  let markAsReadCommand = MarkStatusCommand(initialArticles: articles, markingRead: true, undoManager: undoManager) else {
			return
		}
		runCommand(markAsReadCommand)
	}
	
	func deleteItems(item: SidebarItem) {
//		#if os(macOS)
//		if selectedFeeds.count > 0 {
//			for feed in selectedFeeds {
//				if feed is WebFeed {
//					print(feed.nameForDisplay)
//					let account = (feed as! WebFeed).account
//					account?.removeWebFeed(feed as! WebFeed)
//				}
//				if feed is Folder {
//					let account = (feed as! Folder).account
//					account?.removeFolder(feed as! Folder, completion: { (result) in
//						switch result {
//						case .success( _):
//							print("Deleted folder")
//						case .failure(let err):
//							print(err.localizedDescription)
//						}
//					})
//				}
//			}
//		}
//		#else
//		if item.feed is WebFeed {
//			let account = (item.feed as! WebFeed).account
//			account?.removeWebFeed(item.feed as! WebFeed)
//		}
//		if item.feed is Folder {
//			let account = (item.feed as! Folder).account
//			account?.removeFolder(item.feed as! Folder, completion: { (result) in
//				switch result {
//				case .success( _):
//					print("Deleted folder")
//				case .failure(let err):
//					print(err.localizedDescription)
//				}
//			})
//		}
//		#endif
	}
}



// MARK: Private

private extension SidebarModel {
	
	// MARK: Subscriptions
	
	func subscribeToSelectedFeedChanges() {
		let selectedFeedIdentifersPublisher = $selectedFeedIdentifiers
			.map { [weak self] feedIDs -> [Feed] in
				return feedIDs.compactMap { self?.findFeed($0) }
			}
		
		let selectedFeedIdentiferPublisher = $selectedFeedIdentifier
			.compactMap { [weak self] feedID -> [Feed]? in
				if let feedID = feedID, let feed = self?.findFeed(feedID) {
					return [feed]
				} else {
					return nil
				}
			}
		
		selectedFeedsPublisher = selectedFeedIdentifersPublisher
			.merge(with: selectedFeedIdentiferPublisher)
			.removeDuplicates(by: { previousFeeds, currentFeeds in
				return previousFeeds.elementsEqual(currentFeeds, by: { $0.feedID == $1.feedID })
			})
			.eraseToAnyPublisher()
	}
	
	func subscribeToRebuildSidebarItemsEvents() {
		guard let selectedFeedsPublisher = selectedFeedsPublisher else { return }
		
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
		
		let kickStarter = Notification(name: Notification.Name(rawValue: "Kick Starter"))
		
		sidebarItemsPublisher = sidebarRebuildPublishers
			.prepend(kickStarter)
			.debounce(for: .milliseconds(500), scheduler: RunLoop.main)
			.combineLatest($isReadFiltered.removeDuplicates(), selectedFeedsPublisher)
			.compactMap {  [weak self] _, readFilter, selectedFeeds in
				self?.rebuildSidebarItems(isReadFiltered: readFilter, selectedFeeds: selectedFeeds)
			}
			.eraseToAnyPublisher()
	}
	
	func subscribeToNextUnread() {
		guard let sidebarItemsPublisher = sidebarItemsPublisher, let selectedFeedsPublisher = selectedFeedsPublisher else { return }

		selectNextUnread
			.withLatestFrom(sidebarItemsPublisher, selectedFeedsPublisher)
			.compactMap { [weak self] (sidebarItems, selectedFeeds) in
				return self?.nextUnread(sidebarItems: sidebarItems, selectedFeeds: selectedFeeds)
			}
			.sink { [weak self] nextFeedID in
				self?.select(nextFeedID)
			}
			.store(in: &cancellables)
	}
	
	// MARK: Sidebar Building
	
	func sort(_ folders: Set<Folder>) -> [Folder] {
		return folders.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
	}

	func sort(_ feeds: Set<WebFeed>) -> [Feed] {
		return feeds.sorted(by: { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending })
	}
	
	func rebuildSidebarItems(isReadFiltered: Bool, selectedFeeds: [Feed]) -> [SidebarItem] {
		var items = [SidebarItem]()
		guard let delegate = delegate else { return items }
		
		var smartFeedControllerItem = SidebarItem(SmartFeedsController.shared)
		for feed in SmartFeedsController.shared.smartFeeds {
// It looks like SwiftUI loses its mind when the last element in a section is removed.  Don't filter
// the smartfeeds yet or we crash about everytime because Starred is almost always filtered
//			if !isReadFiltered || feed.unreadCount > 0 {
				smartFeedControllerItem.addChild(SidebarItem(feed, unreadCount: delegate.unreadCount(for: feed)))
//			}
		}
		items.append(smartFeedControllerItem)

		let selectedFeedIDs = Set(selectedFeeds.map { $0.feedID })
		
		for account in AccountManager.shared.sortedActiveAccounts {
			var accountItem = SidebarItem(account)
			
			for webFeed in sort(account.topLevelWebFeeds) {
				if !isReadFiltered || !(webFeed.unreadCount < 1 && !selectedFeedIDs.contains(webFeed.feedID)) {
					accountItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
				}
			}
			
			for folder in sort(account.folders ?? Set<Folder>()) {
				if !isReadFiltered || !(folder.unreadCount < 1 && !selectedFeedIDs.contains(folder.feedID)) {
					var folderItem = SidebarItem(folder, unreadCount: delegate.unreadCount(for: folder))
					for webFeed in sort(folder.topLevelWebFeeds) {
						if !isReadFiltered || !(webFeed.unreadCount < 1 && !selectedFeedIDs.contains(webFeed.feedID)) {
							folderItem.addChild(SidebarItem(webFeed, unreadCount: delegate.unreadCount(for: webFeed)))
						}
					}
					accountItem.addChild(folderItem)
				}
			}

			items.append(accountItem)
		}
		
		return items
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
	
	func nextUnread(sidebarItems: [SidebarItem], selectedFeeds: [Feed]) -> FeedIdentifier? {
		guard let startFeed = selectedFeeds.first ?? sidebarItems.first?.children.first?.feed else { return nil }

		if let feedID = nextUnread(sidebarItems: sidebarItems, startingAt: startFeed) {
			return feedID
		} else {
			if let firstFeed = sidebarItems.first?.children.first?.feed {
				return nextUnread(sidebarItems: sidebarItems, startingAt: firstFeed)
			}
		}
		
		return nil
	}
	
	@discardableResult
	func nextUnread(sidebarItems: [SidebarItem], startingAt: Feed) -> FeedIdentifier? {
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

		return nextSidebarItem?.feed?.feedID
	}

	func select(_ feedID: FeedIdentifier) {
		selectedFeedIdentifiers = Set([feedID])
		selectedFeedIdentifier = feedID
	}
	
}
