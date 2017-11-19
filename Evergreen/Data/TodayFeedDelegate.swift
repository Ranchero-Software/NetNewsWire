//
//  TodayFeedDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Account

struct TodayFeedDelegate: PseudoFeedDelegate {

	let nameForDisplay = NSLocalizedString("Today", comment: "Today pseudo-feed title")

	func fetchUnreadCount(for account: Account, callback: @escaping (Int) -> Void) {

		account.fetchUnreadCountForToday(callback)
	}
}
