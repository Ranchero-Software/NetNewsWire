//
//  StarredFeedDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Data
import Account


struct StarredFeedDelegate: SmartFeedDelegate {

	let nameForDisplay = NSLocalizedString("Starred", comment: "Starred pseudo-feed title")

	func fetchUnreadCount(for account: Account, callback: @escaping (Int) -> Void) {

		account.fetchUnreadCountForStarredArticles(callback)
	}
}
