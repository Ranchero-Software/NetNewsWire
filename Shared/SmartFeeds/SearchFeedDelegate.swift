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

struct SearchFeedDelegate: SmartFeedDelegate {

	var nameForDisplay: String {
		return nameForDisplayPrefix + searchString
	}

	let nameForDisplayPrefix = NSLocalizedString("Search: ", comment: "Search smart feed title prefix")
	let searchString: String
	let fetchType: FetchType
	var smallIcon: RSImage? = AppAssets.searchFeedImage

	init(searchString: String) {
		self.searchString = searchString
		self.fetchType = .search(searchString)
	}

	func fetchUnreadCount(for: Account, callback: @escaping (Int) -> Void) {
		// TODO: after 5.0
	}
}

