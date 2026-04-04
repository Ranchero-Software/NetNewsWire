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
	private(set) var feedReadFilterOverrides = FeedReadFilterOverrides()
	private var foldersShowingReadArticles = [String: Set<String>]() // accountID: Set<folder.nameForDisplay>

	func copy(from stateRestorationInfo: StateRestorationInfo) {
		smartFeedsHidingReadArticles = stateRestorationInfo.smartFeedsHidingReadArticles
		feedReadFilterOverrides = stateRestorationInfo.feedReadFilterOverrides
		foldersShowingReadArticles = stateRestorationInfo.foldersShowingReadArticles
	}

	func save() {
		saveSmartFeedsHidingReadArticles()
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

	func feedHasOverride(accountID: String, feedID: String) -> Bool {
		feedReadFilterOverrides.hasOverride(accountID: accountID, feedID: feedID)
	}

	func clearFeedOverride(accountID: String, feedID: String) {
		feedReadFilterOverrides.clearOverride(accountID: accountID, feedID: feedID)
		saveFeedReadFilterOverrides()
	}

	func setFeedOverride(accountID: String, feedID: String, hiding: Bool) {
		feedReadFilterOverrides.setOverride(accountID: accountID, feedID: feedID, hiding ? .hide : .show)
		saveFeedReadFilterOverrides()
	}

	func clearAllFeedOverrides(accountID: String) {
		feedReadFilterOverrides.clearAll(accountID: accountID)
		saveFeedReadFilterOverrides()
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
			if hiding {
				smartFeedsHidingReadArticles.insert(id)
			} else {
				smartFeedsHidingReadArticles.remove(id)
			}
			saveSmartFeedsHidingReadArticles()

		case .feed(let accountID, let feedID):
			feedReadFilterOverrides.setOverride(accountID: accountID, feedID: feedID, hiding ? .hide : .show)
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
		var cleanedOverrides = FeedReadFilterOverrides()
		for entry in feedReadFilterOverrides.allFeeds() {
			guard let account = AccountManager.shared.existingAccount(accountID: entry.accountID),
				  account.existingFeed(withFeedID: entry.feedID) != nil else {
				continue
			}
			cleanedOverrides.setOverride(accountID: entry.accountID, feedID: entry.feedID, entry.override)
		}

		feedReadFilterOverrides = cleanedOverrides
		AppDefaults.shared.feedReadFilterOverrides = feedReadFilterOverrides
	}

	func saveSmartFeedsHidingReadArticles() {
		AppDefaults.shared.smartFeedsHidingReadArticles = smartFeedsHidingReadArticles
	}
}
