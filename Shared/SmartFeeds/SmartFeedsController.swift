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

@MainActor final class SmartFeedsController: DisplayNameProvider, ContainerIdentifiable {
	nonisolated let containerID: ContainerIdentifier? = ContainerIdentifier.smartFeedController

	public static let shared = SmartFeedsController()
	let nameForDisplay = NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")

	var smartFeeds = [SidebarItem]()
	let todayFeed = SmartFeed(delegate: TodayFeedDelegate())
	let unreadFeed = UnreadFeed()
	let starredFeed = SmartFeed(delegate: StarredFeedDelegate())

	/// The smart feeds shown in the sidebar. All smart feeds exist regardless.
	var shownSmartFeeds: [SidebarItem] {
		var feeds = [SidebarItem]()
		if AppDefaults.showTodayFeed {
			feeds.append(todayFeed)
		}
		if AppDefaults.showUnreadFeed {
			feeds.append(unreadFeed)
		}
		if AppDefaults.showStarredFeed {
			feeds.append(starredFeed)
		}
		return feeds
	}

	func isShown(_ smartFeed: SidebarItem) -> Bool {
		shownSmartFeeds.contains { $0.sidebarItemID == smartFeed.sidebarItemID }
	}

	private init() {
		self.smartFeeds = [todayFeed, unreadFeed, starredFeed]
	}

	func find(by identifier: SidebarItemIdentifier) -> PseudoFeed? {
		switch identifier {
		case .smartFeed(let stringIdentifer):
			switch stringIdentifer {
			case String(describing: TodayFeedDelegate.self):
				return todayFeed
			case String(describing: UnreadFeed.self):
				return unreadFeed
			case String(describing: StarredFeedDelegate.self):
				return starredFeed
			default:
				return nil
			}
		default:
			return nil
		}
	}

}
