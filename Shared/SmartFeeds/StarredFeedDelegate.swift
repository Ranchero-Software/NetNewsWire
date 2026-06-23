//
//  StarredFeedDelegate.swift
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

@MainActor struct StarredFeedDelegate: SmartFeedDelegate {

	var sidebarItemID: SidebarItemIdentifier? {
		return SidebarItemIdentifier.smartFeed(String(describing: StarredFeedDelegate.self))
	}

	let nameForDisplay = NSLocalizedString("Starred", comment: "Starred")
	let fetchType: FetchType = .starred(nil)
	var smallIcon: IconImage? {
		Assets.Images.starredFeed
	}
	func fetchUnreadCount(account: Account) async -> Int {
		await account.fetchUnreadCountForStarredArticlesAsync()
	}
}
