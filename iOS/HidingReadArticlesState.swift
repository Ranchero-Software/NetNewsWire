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
	private var hideReadArticles = AppDefaults.shared.hideReadArticles

	func copy(from stateRestorationInfo: StateRestorationInfo) {
		hideReadArticles = stateRestorationInfo.hideReadArticles
	}

	func save() {
		AppDefaults.shared.hideReadArticles = hideReadArticles
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

		hideReadArticles.toggle()
		save()
	}

	func isHidingReadArticles(for sidebarItemID: SidebarItemIdentifier) -> Bool {
		isUnreadSmartFeed(sidebarItemID) ? true : hideReadArticles
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
