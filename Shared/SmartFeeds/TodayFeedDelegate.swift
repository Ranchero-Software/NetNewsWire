//
//  TodayFeedDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Account

struct TodayFeedDelegate: SmartFeedDelegate {

	let nameForDisplay = NSLocalizedString("Today", comment: "Today pseudo-feed title")
	let fetchType = FetchType.today

	func fetchUnreadCount(for account: Account, callback: @escaping (Int) -> Void) {
		account.fetchUnreadCountForToday(callback)
	}
}

