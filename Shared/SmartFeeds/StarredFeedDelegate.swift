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
import Account

// Main thread only.

struct StarredFeedDelegate: SmartFeedDelegate {

	var feedID: FeedIdentifier? {
		return FeedIdentifier.smartFeed(String(describing: StarredFeedDelegate.self))
	}

	let nameForDisplay = NSLocalizedString("Starred", comment: "Starred pseudo-feed title")
	let fetchType: FetchType = .starred
	var smallIcon: IconImage? = AppAssets.starredFeedImage

	func fetchUnreadCount(for account: Account, completion: @escaping (Int) -> Void) {
		account.fetchUnreadCountForStarredArticles(completion)
	}
}
