//
//  SmartFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Articles
import ArticlesDatabase
import Account

@MainActor final class SmartFeed: PseudoFeed {
	var account: Account?

	public var defaultReadFilterType: ReadFilterType {
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

	init(delegate: SmartFeedDelegate) {
		self.delegate = delegate
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		queueFetchUnreadCounts() // Fetch unread count at startup
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AppDelegate {
			queueFetchUnreadCounts()
		}
	}

	@objc func fetchUnreadCounts() {
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
		} else {
			for account in activeAccounts {
				fetchUnreadCount(account: account)
			}
		}
	}

}

extension SmartFeed: ArticleFetcher {

	func fetchArticles() throws -> Set<Article> {
		try delegate.fetchArticles()
	}

	func fetchArticlesAsync() async throws -> Set<Article> {
		try await delegate.fetchArticlesAsync()
	}

	func fetchUnreadArticles() throws -> Set<Article> {
		try delegate.fetchUnreadArticles()
	}

	func fetchUnreadArticlesAsync() async throws -> Set<Article> {
		try await delegate.fetchUnreadArticlesAsync()
	}
}

private extension SmartFeed {

	func queueFetchUnreadCounts() {
		CoalescingQueue.standard.add(self, #selector(fetchUnreadCounts))
	}

	func fetchUnreadCount(account: Account) {
		Task { @MainActor in
			guard let unreadCount = try? await delegate.fetchUnreadCount(account: account) else {
				return
			}
			unreadCounts[account.accountID] = unreadCount
			updateUnreadCount()
		}
	}

	func updateUnreadCount() {
		var updatedUnreadCount = 0
		for account in AccountManager.shared.activeAccounts {
			if let oneUnreadCount = unreadCounts[account.accountID] {
				updatedUnreadCount += oneUnreadCount
			}
		}

		unreadCount = updatedUnreadCount
	}
}
