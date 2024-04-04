//
//  StarredFeedDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import ArticlesDatabase
import Account

// Main thread only.

@MainActor struct StarredFeedDelegate: SmartFeedDelegate {

	var sidebarItemID: SidebarItemIdentifier? {
		return SidebarItemIdentifier.smartFeed(String(describing: StarredFeedDelegate.self))
	}

	let nameForDisplay = NSLocalizedString("Starred", comment: "Starred pseudo-feed title")
	let fetchType: FetchType = .starred(nil)
	var smallIcon: IconImage? {
		return AppAssets.starredFeedImage
	}

	func unreadCount(account: Account) async -> Int {
		
		(try? await account.unreadCountForStarredArticles()) ?? 0
	}
}
