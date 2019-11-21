//
//  SmartFeedsController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

final class SmartFeedsController: DisplayNameProvider {

	public static let shared = SmartFeedsController()
	let nameForDisplay = NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")

	var smartFeeds = [Feed]()
	let todayFeed = SmartFeed(delegate: TodayFeedDelegate())
	let unreadFeed = UnreadFeed()
	let starredFeed = SmartFeed(delegate: StarredFeedDelegate())

	private init() {
		self.smartFeeds = [todayFeed, unreadFeed, starredFeed]
	}
	
	func find(by identifier: String) -> PseudoFeed? {
		switch identifier {
		case String(describing: TodayFeedDelegate.self):
			return todayFeed
		case String(describing: UnreadFeed.self):
			return unreadFeed
		case String(describing: StarredFeedDelegate.self):
			return starredFeed
		default:
			return nil
		}
	}
	
}
