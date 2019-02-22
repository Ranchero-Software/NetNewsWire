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
import Account

protocol SmartFeedDelegate: DisplayNameProvider, ArticleFetcher {
	func fetchUnreadCount(for: Account, callback: @escaping (Int) -> Void)
}

final class SmartFeed: PseudoFeed {

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

	var pasteboardWriter: NSPasteboardWriting {
		return SmartFeedPasteboardWriter(smartFeed: self)
	}

	private let delegate: SmartFeedDelegate
	private var unreadCounts = [Account: Int]()

	init(delegate: SmartFeedDelegate) {
		self.delegate = delegate
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		queueFetchUnreadCounts() // Fetch unread count at startup
	}

	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is Account {
			queueFetchUnreadCounts()
		}
	}

	@objc func fetchUnreadCounts() {
		AccountManager.shared.accounts.forEach { self.fetchUnreadCount(for: $0) }
	}
}

extension SmartFeed: ArticleFetcher {

	func fetchArticles() -> Set<Article> {
		return delegate.fetchArticles()
	}

	func fetchUnreadArticles() -> Set<Article> {
		return delegate.fetchUnreadArticles()
	}
}

private extension SmartFeed {

	func queueFetchUnreadCounts() {
		CoalescingQueue.standard.add(self, #selector(fetchUnreadCounts))
	}

	func fetchUnreadCount(for account: Account) {
		delegate.fetchUnreadCount(for: account) { (accountUnreadCount) in
			self.unreadCounts[account] = accountUnreadCount
			self.updateUnreadCount()
		}
	}

	func updateUnreadCount() {
		unreadCount = AccountManager.shared.accounts.reduce(0) { (result, account) -> Int in
			if let oneUnreadCount = unreadCounts[account] {
				return result + oneUnreadCount
			}
			return result
		}
	}
}
