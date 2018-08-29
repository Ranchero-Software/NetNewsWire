//
//  SmartFeedsController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

final class SmartFeedsController: DisplayNameProvider {

	public static let shared = SmartFeedsController()
	let nameForDisplay = NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")

	var smartFeeds = [AnyObject]()
	let todayFeed = SmartFeed(delegate: TodayFeedDelegate())
	let unreadFeed = UnreadFeed()
	let starredFeed = SmartFeed(delegate: StarredFeedDelegate())

	private init() {

		self.smartFeeds = [todayFeed, unreadFeed, starredFeed]
	}
}
