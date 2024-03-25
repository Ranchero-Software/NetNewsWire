//
//  SmartFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import ArticlesDatabase
import Account
import Database
import Core

final class SmartFeed: PseudoFeed {

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

	private let delegate: SmartFeedDelegate
	private var unreadCounts = [String: Int]()

	@MainActor init(delegate: SmartFeedDelegate) {
		self.delegate = delegate
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		queueFetchUnreadCounts() // Fetch unread count at startup
	}

	@MainActor @objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AppDelegate {
			queueFetchUnreadCounts()
		}
	}

	@MainActor @objc func fetchUnreadCounts() {

		let activeAccounts = AccountManager.shared.activeAccounts

		// Remove any accounts that are no longer active or have been deleted
		let activeAccountIDs = activeAccounts.map { $0.accountID }
		unreadCounts.keys.forEach { accountID in
			if !activeAccountIDs.contains(accountID) {
				unreadCounts.removeValue(forKey: accountID)
			}
		}

		if activeAccounts.isEmpty {
			updateUnreadCount()
			return
		}
		
		Task { @MainActor in
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

	@MainActor func queueFetchUnreadCounts() {
		CoalescingQueue.standard.add(self, #selector(fetchUnreadCounts))
	}

	@MainActor func fetchUnreadCount(for account: Account) async {

		let unreadCount = await delegate.unreadCount(account: account)
		unreadCounts[account.accountID] = unreadCount
		
		updateUnreadCount()
	}

	@MainActor func updateUnreadCount() {

		var unread = 0
		for account in AccountManager.shared.activeAccounts {
			unread = unread + (unreadCounts[account.accountID] ?? 0)
		}

		unreadCount = unread
	}
}
