//
//  SearchTimelineFeedDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/31/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account
import Articles

struct SearchTimelineFeedDelegate: SmartFeedDelegate {

	var nameForDisplay: String {
		return nameForDisplayPrefix + searchString
	}

	let nameForDisplayPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
	let searchString: String
	let fetchType: FetchType
	var smallIcon: RSImage? = AppAssets.searchFeedImage

	init(searchString: String, articleIDs: Set<String>) {
		self.searchString = searchString
		self.fetchType = .searchWithArticleIDs(searchString, articleIDs)
	}

	func fetchUnreadCount(for: Account, callback: @escaping (Int) -> Void) {
		// TODO: after 5.0
	}
}
