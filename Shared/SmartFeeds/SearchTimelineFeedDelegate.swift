//
//  SearchTimelineFeedDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/31/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Articles
import Images

@MainActor struct SearchTimelineFeedDelegate: SmartFeedDelegate {

	var sidebarItemID: SidebarItemIdentifier? {
		return SidebarItemIdentifier.smartFeed(String(describing: SearchTimelineFeedDelegate.self))
	}

	var nameForDisplay: String {
		return nameForDisplayPrefix + searchString
	}

	let nameForDisplayPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
	let searchString: String
	let fetchType: FetchType
	var smallIcon: IconImage? = AppAsset.searchFeedImage

	init(searchString: String, articleIDs: Set<String>) {
		self.searchString = searchString
		self.fetchType = .searchWithArticleIDs(searchString, articleIDs)
	}

	func unreadCount(account: Account) async -> Int {

		return 0
	}
}
