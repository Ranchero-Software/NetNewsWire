//
//  SmartFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account
import Core
import Images

@MainActor final class SmartFeed: PseudoFeed {

	var account: Account? = nil

	var defaultReadFilterType: ReadFilterType {
		return .none
	}

	var sidebarItemID: SidebarItemIdentifier? {
		delegate.sidebarItemID
	}

	var nameForDisplay: String {
		return delegate.nameForDisplay
	}

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	var smallIcon: IconImage? {
		return delegate.smallIcon
	}
	
	#if os(macOS)
	var pasteboardWriter: NSPasteboardWriting {
		return SmartFeedPasteboardWriter(smartFeed: self)
	}
	#endif

	private let fetchUnreadCountsQueue = CoalescingQueue(name: "SmartFeed", interval: 1.0)

	private var fetchUnreadCountsTask: Task<Void, Never>?
	private let delegate: SmartFeedDelegate
	private var unreadCounts = [String: Int]()

	init(delegate: SmartFeedDelegate) {
		self.delegate = delegate
		NotificationCenter.default.addObserver(self, selector: #selector(appUnreadCountDidChange(_:)), name: .appUnreadCountDidChange, object: nil)
		queueFetchUnreadCounts() // Fetch unread count at startup
	}

	@objc func appUnreadCountDidChange(_ note: Notification) {
		
		queueFetchUnreadCounts()
	}

	@objc func fetchUnreadCounts() {
		
		Task {
			
			let activeAccounts = AccountManager.shared.activeAccounts
			
			// Remove any accounts that are no longer active or have been deleted
			let activeAccountIDs = activeAccounts.map { $0.accountID }
			for accountID in unreadCounts.keys {
				if !activeAccountIDs.contains(accountID) {
					unreadCounts.removeValue(forKey: accountID)
				}
			}
			
			if activeAccounts.isEmpty {
				updateUnreadCount()
				return
			}
			
			for account in activeAccounts {
				await fetchUnreadCount(for: account)
			}
		}
	}
}

extension SmartFeed: ArticleFetcher {

	func fetchArticles() async throws -> Set<Article> {
		
		try await delegate.fetchArticles()
	}
	
	func fetchUnreadArticles() async throws -> Set<Article> {

		try await delegate.fetchUnreadArticles()
	}
}

private extension SmartFeed {

	func queueFetchUnreadCounts() {

		fetchUnreadCountsQueue.add(self, #selector(fetchUnreadCounts))
	}

	func fetchUnreadCount(for account: Account) async {

		let unreadCount = await delegate.unreadCount(account: account)
		unreadCounts[account.accountID] = unreadCount
		
		updateUnreadCount()
	}

	func updateUnreadCount() {

		var unread = 0
		for account in AccountManager.shared.activeAccounts {
			unread = unread + (unreadCounts[account.accountID] ?? 0)
		}

		unreadCount = unread
	}
}

