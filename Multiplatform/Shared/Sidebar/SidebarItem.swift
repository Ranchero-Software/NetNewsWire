//
//  SidebarItem.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/29/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

public enum SidebarItemIdentifier: Hashable, Equatable {
	case smartFeedController
	case account(String)
	case feed(FeedIdentifier)
}

public enum RepresentedType {
	case feed, pseudoFeed, account, unknown
}

struct SidebarItem: Identifiable {
	
	var id: SidebarItemIdentifier
	var represented: Any
	var children: [SidebarItem]?
	
	var unreadCount: Int
	
	var nameForDisplay: String {
		guard let displayNameProvider = represented as? DisplayNameProvider else { return "" }
		return displayNameProvider.nameForDisplay
	}
	
	var feed: Feed? {
		represented as? Feed
	}
	
	var representedType: RepresentedType {
		switch type(of: represented) {
		case is SmartFeed.Type:
			return .pseudoFeed
		case is UnreadFeed.Type:
			return .pseudoFeed
		case is WebFeed.Type:
			return .feed
		case is Account.Type:
			return .account
		default:
			return .unknown
		}
	}
	
	init(_ smartFeedsController: SmartFeedsController) {
		self.id = .smartFeedController
		self.represented = smartFeedsController
		self.children = [SidebarItem]()
		self.unreadCount = 0
	}

	init(_ account: Account) {
		self.id = .account(account.accountID)
		self.represented = account
		self.children = [SidebarItem]()
		self.unreadCount = account.unreadCount
	}

	init(_ feed: Feed, unreadCount: Int) {
		self.id = .feed(feed.feedID!)
		self.represented = feed
		self.unreadCount = unreadCount
		if let container = feed as? Container, container.hasAtLeastOneWebFeed() {
			self.children = [SidebarItem]()
		}
	}

	mutating func addChild(_ sidebarItem: SidebarItem) {
		children?.append(sidebarItem)
	}
	
}
