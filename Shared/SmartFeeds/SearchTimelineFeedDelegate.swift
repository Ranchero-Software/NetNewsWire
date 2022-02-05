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
import ArticlesDatabase

struct SearchTimelineFeedDelegate: SmartFeedDelegate {

	var feedID: FeedIdentifier? {
		return FeedIdentifier.smartFeed(String(describing: SearchTimelineFeedDelegate.self))
	}

	var nameForDisplay: String {
		return nameForDisplayPrefix + searchString
	}

	let nameForDisplayPrefix = NSLocalizedString("SEARCH_FEED_PLACEHOLDER", comment: "Search smart feed title prefix")
	let searchString: String
	let fetchType: FetchType
	var smallIcon: IconImage? = AppAssets.searchFeedImage

	init(searchString: String, articleIDs: Set<String>) {
		self.searchString = searchString
		self.fetchType = .searchWithArticleIDs(searchString, articleIDs)
	}

	func fetchUnreadCount(for: Account, completion: @escaping SingleUnreadCountCompletionBlock) {
		// TODO: after 5.0
	}
}
