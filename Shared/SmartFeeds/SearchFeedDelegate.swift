//
//  SearchFeedDelegate.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account
import Articles
import ArticlesDatabase
import Images

struct SearchFeedDelegate: SmartFeedDelegate {

	var sidebarItemID: SidebarItemIdentifier? {
		return SidebarItemIdentifier.smartFeed(String(describing: SearchFeedDelegate.self))
	}

	var nameForDisplay: String {
		return nameForDisplayPrefix + searchString
	}

	let nameForDisplayPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
	let searchString: String
	let fetchType: FetchType
	var smallIcon: IconImage? = Assets.Images.searchFeed

	init(searchString: String) {
		self.searchString = searchString
		self.fetchType = .search(searchString)
	}

	func fetchUnreadCount(account: Account) async -> Int {
		// TODO: after 5.0
		0
	}
}
