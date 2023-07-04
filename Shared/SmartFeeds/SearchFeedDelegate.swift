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

struct SearchFeedDelegate: SmartFeedDelegate {

	var itemID: ItemIdentifier? {
		return ItemIdentifier.smartFeed(String(describing: SearchFeedDelegate.self))
	}

	var nameForDisplay: String {
		return nameForDisplayPrefix + searchString
	}

	let nameForDisplayPrefix = NSLocalizedString("textfield.placeholder.search", comment: "Search: ")
	let searchString: String
	let fetchType: FetchType
	var smallIcon: IconImage? = AppAssets.searchFeedImage

	init(searchString: String) {
		self.searchString = searchString
		self.fetchType = .search(searchString)
	}

	func fetchUnreadCount(for: Account, completion: @escaping SingleUnreadCountCompletionBlock) {
		// TODO: after 5.0
	}

	func fetchUnreadArticlesBetween(before: Date? = nil, after: Date? = nil) throws -> Set<Article> {
		fatalError("Function not implemented.")
	}
	
}

