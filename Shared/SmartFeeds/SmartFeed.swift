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
import Images

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
	private var isFetchingUnreadCounts = false
	private var needsRefetch = false

	init(delegate: SmartFeedDelegate) {
		self.delegate = delegate
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		// Refetch on activation and on day change to prevent staleness.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/3936>
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidBecomeActive(_:)), name: .appDidBecomeActive, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleCalendarDayChanged(_:)), name: .NSCalendarDayChanged, object: nil)
		queueFetchUnreadCounts() // Fetch unread count at startup
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AppDelegate {
			queueFetchUnreadCounts()
		}
	}

	@objc func handleAppDidBecomeActive(_ note: Notification) {
		queueFetchUnreadCounts()
	}

	// NSCalendarDayChanged isn't guaranteed to arrive on the main thread.
	@objc nonisolated func handleCalendarDayChanged(_ note: Notification) {
		Task { @MainActor in
			self.queueFetchUnreadCounts()
		}
	}

	@objc func fetchUnreadCounts() {
		// Unread counts change continuously during a refresh. Only one round of
		// database queries is in flight at a time, and one more is queued
		// afterward if anything changed while it ran.
		if isFetchingUnreadCounts {
			needsRefetch = true
			return
		}

		let activeAccounts = AccountManager.shared.activeAccounts
		if activeAccounts.isEmpty {
			unreadCount = 0
			return
		}

		isFetchingUnreadCounts = true
		Task { @MainActor in
			var updatedUnreadCount = 0
			for account in activeAccounts {
				updatedUnreadCount += await delegate.fetchUnreadCount(account: account)
			}
			unreadCount = updatedUnreadCount

			isFetchingUnreadCounts = false
			if needsRefetch {
				needsRefetch = false
				queueFetchUnreadCounts()
			}
		}
	}
}

extension SmartFeed: ArticleFetcher {

	func fetchArticles() -> Set<Article> {
		delegate.fetchArticles()
	}

	func fetchArticlesAsync() async -> Set<Article> {
		await delegate.fetchArticlesAsync()
	}

	func fetchUnreadArticles() -> Set<Article> {
		delegate.fetchUnreadArticles()
	}

	func fetchUnreadArticlesAsync() async -> Set<Article> {
		await delegate.fetchUnreadArticlesAsync()
	}
}

private extension SmartFeed {

	func queueFetchUnreadCounts() {
		CoalescingQueue.standard.add(self, #selector(fetchUnreadCounts))
	}
}
