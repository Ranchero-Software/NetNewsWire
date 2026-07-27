//
//  HidingReadArticlesState.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 12/8/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import Account

@MainActor final class HidingReadArticlesState {
	func copy(from _: StateRestorationInfo) {
		// Uses global read filter state from AppDefaults.hideReadFeeds.
	}

	func save() {
		// Clear per-sidebar-item legacy state now that read filtering is global.
		AppDefaults.shared.smartFeedsHidingReadArticles = []
		AppDefaults.shared.feedsHidingReadArticles = [:]
		AppDefaults.shared.foldersShowingReadArticles = [:]
	}

	func toggleHidingReadArticles(for sidebarItemID: SidebarItemIdentifier) {
		assert(canToggleHidingReadArticles(for: sidebarItemID))
		if !canToggleHidingReadArticles(for: sidebarItemID) {
			return
		}

		AppDefaults.shared.hideReadFeeds.toggle()
		save()
	}

	func isHidingReadArticles(for sidebarItemID: SidebarItemIdentifier) -> Bool {
		isUnreadSmartFeed(sidebarItemID) ? true : AppDefaults.shared.hideReadFeeds
	}

	func canToggleHidingReadArticles(for sidebarItemID: SidebarItemIdentifier) -> Bool {
		// The only item that can't be toggled is the unread smart feed.
		!isUnreadSmartFeed(sidebarItemID)
	}
}

private extension HidingReadArticlesState {

	func isUnreadSmartFeed(_ sidebarItemID: SidebarItemIdentifier) -> Bool {
		sidebarItemID == SmartFeedsController.shared.unreadFeed.sidebarItemID
	}
}
