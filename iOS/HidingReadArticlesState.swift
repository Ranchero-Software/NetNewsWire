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
	private var smartFeedsHidingReadArticles = Set<String>()
	private var smartFeedsShowingReadArticles = Set<String>()
	private(set) var feedReadFilterOverrides = FeedReadFilterOverrides()
	private var foldersShowingReadArticles = [String: Set<String>]() // accountID: Set<folder.nameForDisplay>

	func copy(from stateRestorationInfo: StateRestorationInfo) {
		smartFeedsHidingReadArticles = stateRestorationInfo.smartFeedsHidingReadArticles
		smartFeedsShowingReadArticles = stateRestorationInfo.smartFeedsShowingReadArticles
		feedReadFilterOverrides = stateRestorationInfo.feedReadFilterOverrides
		foldersShowingReadArticles = stateRestorationInfo.foldersShowingReadArticles
	}

	func save() {
		saveSmartFeedsReadFilterState()
		saveFeedReadFilterOverrides()
		saveFoldersShowingReadArticles()
	}

	func reloadFeedOverridesFromDefaults() {
		feedReadFilterOverrides = AppDefaults.shared.feedReadFilterOverrides
	}

	func toggleHidingReadArticles(for sidebarItemID: SidebarItemIdentifier) {
		assert(canToggleHidingReadArticles(for: sidebarItemID))
		if !canToggleHidingReadArticles(for: sidebarItemID) {
			return
		}

		let hidesReadArticles = isHidingReadArticles(for: sidebarItemID)
		let toggledValue = !hidesReadArticles
		saveHidingReadArticles(for: sidebarItemID, hiding: toggledValue)
	}

	func isHidingReadArticles(for sidebarItemID: SidebarItemIdentifier) -> Bool {
		switch sidebarItemID {

		case .smartFeed(let id):
			if isUnreadSmartFeed(sidebarItemID) {
				return true
			}
			if smartFeedsHidingReadArticles.contains(id) {
				return true
			}
			if smartFeedsShowingReadArticles.contains(id) {
				return false
			}
			return AppDefaults.shared.hideReadArticles

		case .feed(let accountID, let feedID):
			if let override = feedReadFilterOverrides.override(accountID: accountID, feedID: feedID) {
				return override == .hide
			}
			return AppDefaults.shared.hideReadArticles

		case .folder(let accountID, let folderName):
			// Folders hide read articles by default, so we check if not showing read articles.
			var isHidingReadArticles = true
			if let folderNames = foldersShowingReadArticles[accountID] {
				isHidingReadArticles = !folderNames.contains(folderName)
			}
			return isHidingReadArticles
		}
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

	func saveHidingReadArticles(for sidebarItemID: SidebarItemIdentifier, hiding: Bool) {
		switch sidebarItemID {

		case .smartFeed(let id):
			if isUnreadSmartFeed(sidebarItemID) {
				return
			}
			// Stored both ways so that showing read articles sticks when the
			// global setting hides them.
			if hiding {
				smartFeedsHidingReadArticles.insert(id)
				smartFeedsShowingReadArticles.remove(id)
			} else {
				smartFeedsHidingReadArticles.remove(id)
				smartFeedsShowingReadArticles.insert(id)
			}
			saveSmartFeedsReadFilterState()

		case .feed(let accountID, let feedID):
			feedReadFilterOverrides.setOverride(hiding ? .hide : .show, accountID: accountID, feedID: feedID)
			saveFeedReadFilterOverrides()

		case .folder(let accountID, let folderName):
			// Folders hide read articles by default, so we store the folder
			// only if it's showing read articles.
			if hiding {
				foldersShowingReadArticles[accountID]?.remove(folderName)
			} else {
				var folderNames = foldersShowingReadArticles[accountID] ?? Set<String>()
				folderNames.insert(folderName)
				foldersShowingReadArticles[accountID] = folderNames
			}
			saveFoldersShowingReadArticles()
		}
	}

	func saveFoldersShowingReadArticles() {
		var d = foldersShowingReadArticles

		// Filter out accounts and folders that no longer exist.
		for accountID in Array(d.keys) {
			guard let account = AccountManager.shared.existingAccount(accountID: accountID) else {
				d[accountID] = nil
				continue
			}
			d[accountID] = d[accountID]?.filter { account.existingFolder(withDisplayName: $0) != nil }
		}

		AppDefaults.shared.foldersShowingReadArticles = d
	}

	func saveFeedReadFilterOverrides() {
		// Filter out accounts and feeds that no longer exist.
		feedReadFilterOverrides.removeAll { accountID, feedID in
			AccountManager.shared.existingAccount(accountID: accountID)?.existingFeed(withFeedID: feedID) == nil
		}
		AppDefaults.shared.feedReadFilterOverrides = feedReadFilterOverrides
	}

	func saveSmartFeedsReadFilterState() {
		AppDefaults.shared.smartFeedsHidingReadArticles = smartFeedsHidingReadArticles
		AppDefaults.shared.smartFeedsShowingReadArticles = smartFeedsShowingReadArticles
	}
}
