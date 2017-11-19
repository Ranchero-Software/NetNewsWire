//
//  PseudoFeed.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data
import RSCore
import Account

protocol PseudoFeedDelegate: DisplayNameProvider {

	func fetchUnreadCount(for: Account, callback: (Int) -> Void)
}

final class PseudoFeed: UnreadCountProvider, DisplayNameProvider {

	private var timer: Timer?
	private var unreadCounts = [Account: Int]()
	private let delegate: PseudoFeedDelegate

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

	init(delegate: PseudoFeedDelegate) {

		self.delegate = delegate
	}

	@objc func unreadCountDidChange(_ note: Notification) {

		if let object = note.object, object is Account {
			startTimer()
		}
	}
}

private extension PseudoFeed {

	// MARK: - Unread Counts

	private func fetchUnreadCount(for account: Account) {

		delegate.fetchUnreadCount(for: account) { (accountUnreadCount) in
			unreadCounts[account] = accountUnreadCount
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
		timer = Timer(timeInterval: PseudoFeed.fetchCoalescingDelay, repeats: false, block: { (_) in
			self.fetchUnreadCounts()
			self.stopTimer()
		})
	}
}

