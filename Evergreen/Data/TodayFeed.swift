//
//  TodayFeed.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data
import Account

final class TodayFeed: PseudoFeed {

	let nameForDisplay = NSLocalizedString("Today", comment: "Today pseudo-feed title")

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	private var timer: Timer?
	private var unreadCounts = [Account: Int]()

	init() {

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		startTimer() // Fetch unread count at startup
	}

	@objc func unreadCountDidChange(_ note: Notification) {

		if note.object is Account {
			startTimer()
		}
	}
}

private extension TodayFeed {

	// MARK: - Unread Counts

	private func fetchUnreadCount(for account: Account) {

		account.fetchUnreadCountForToday { (accountUnreadCount) in
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

	private static let fetchCoalescingDelay: TimeInterval = 0.2

	func startTimer() {

		stopTimer()

		timer = Timer.scheduledTimer(withTimeInterval: TodayFeed.fetchCoalescingDelay, repeats: false, block: { (timer) in
			self.fetchUnreadCounts()
			self.stopTimer()
		})
	}
}

