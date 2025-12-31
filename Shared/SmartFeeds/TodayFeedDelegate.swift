//
//  TodayFeedDelegate.swift
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

struct TodayFeedDelegate: SmartFeedDelegate {
	var sidebarItemID: SidebarItemIdentifier? {
		return SidebarItemIdentifier.smartFeed(String(describing: TodayFeedDelegate.self))
	}

	let nameForDisplay = NSLocalizedString("Today", comment: "Today pseudo-feed title")
	let fetchType = FetchType.today(nil)
	var smallIcon: IconImage? {
		Assets.Images.todayFeed
	}

	func fetchUnreadCount(account: Account) async throws -> Int? {
		try await account.fetchUnreadCountForTodayAsync()
	}
}
