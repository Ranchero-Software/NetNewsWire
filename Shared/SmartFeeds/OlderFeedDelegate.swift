//
//  OlderFeedDelegate.swift
//  NetNewsWire
//
//  Created by Bryan Culver on 08/25/22.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Articles
import ArticlesDatabase
import Account

struct OlderFeedDelegate: SmartFeedDelegate {

	var feedID: FeedIdentifier? {
		return FeedIdentifier.smartFeed(String(describing: OlderFeedDelegate.self))
	}

	let nameForDisplay = NSLocalizedString("Old", comment: "Old pseudo-feed title")
	let fetchType = FetchType.older(nil)
	var smallIcon: IconImage? {
		return AppAssets.oldFeedImage
	}

	func fetchUnreadCount(for account: Account, completion: @escaping SingleUnreadCountCompletionBlock) {
		account.fetchUnreadCountForOlder(completion)
	}
}

