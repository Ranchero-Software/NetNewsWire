//
//  SmartFeed.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Data
import Account

protocol SmartFeedDelegate: DisplayNameProvider, ArticleFetcher {

	func fetchUnreadCount(for: Account, callback: @escaping (Int) -> Void)
}

final class SmartFeed: PseudoFeed {

	var nameForDisplay: String {
		get {
			return delegate.nameForDisplay
		}
	}

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	private let delegate: SmartFeedDelegate
	private var timer: Timer?
	private var unreadCounts = [Account: Int]()

	init(delegate: SmartFeedDelegate) {

		self.delegate = delegate
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		startTimer() // Fetch unread count at startup
	}

	@objc func unreadCountDidChange(_ note: Notification) {

		if note.object is Account {
			startTimer()
		}
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

	// MARK: - Unread Counts

	private func fetchUnreadCount(for account: Account) {

		delegate.fetchUnreadCount(for: account) { (accountUnreadCount) in
			self.unreadCounts[account] = accountUnreadCount
			self.updateUnreadCount()
		}
	}

	private func fetchUnreadCounts() {

		AccountManager.shared.accounts.forEach { self.fetchUnreadCount(for: $0) }
	}

	private func updateUnreadCount() {

		unreadCount = AccountManager.shared.accounts.reduce(0) { (result, account) -> Int in
			if let oneUnreadCount = unreadCounts[account] {
				return result + oneUnreadCount
			}
			return result
		}
	}

	// MARK: - Timer

	func stopTimer() {

		if let timer = timer {
			timer.rs_invalidateIfValid()
		}
		timer = nil
	}

	private static let fetchCoalescingDelay: TimeInterval = 0.1

	func startTimer() {

		stopTimer()

		timer = Timer.scheduledTimer(withTimeInterval: SmartFeed.fetchCoalescingDelay, repeats: false, block: { (timer) in
			self.fetchUnreadCounts()
			self.stopTimer()
		})
	}
}
