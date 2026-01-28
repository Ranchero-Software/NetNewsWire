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
	private var feedsHidingReadArticles = [String: Set<String>]() // accountID: Set<feed.feedID>
	private var foldersShowingReadArticles = [String: Set<String>]() // accountID: Set<folder.nameForDisplay>

	func copy(from stateRestorationInfo: StateRestorationInfo) {
		smartFeedsHidingReadArticles = stateRestorationInfo.smartFeedsHidingReadArticles
		feedsHidingReadArticles = stateRestorationInfo.feedsHidingReadArticles
		foldersShowingReadArticles = stateRestorationInfo.foldersShowingReadArticles
	}

	func save() {
		saveSmartFeedsHidingReadArticles()
		saveFeedsHidingReadArticles()
		saveFoldersShowingReadArticles()
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
			return smartFeedsHidingReadArticles.contains(id)

		case .feed(let accountID, let feedID):
			var isHidingReadArticles = false
			if let feedIDs = feedsHidingReadArticles[accountID] {
				isHidingReadArticles = feedIDs.contains(feedID)
			}
			return isHidingReadArticles

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
			if hiding {
				smartFeedsHidingReadArticles.insert(id)
			} else {
				smartFeedsHidingReadArticles.remove(id)
			}
			saveSmartFeedsHidingReadArticles()

		case .feed(let accountID, let feedID):
			if hiding {
				var feedIDs = feedsHidingReadArticles[accountID] ?? Set<String>()
				feedIDs.insert(feedID)
				feedsHidingReadArticles[accountID] = feedIDs
			} else {
				feedsHidingReadArticles[accountID]?.remove(feedID)
			}
			saveFeedsHidingReadArticles()

		case .folder(let accountID, let folderName):
			// Folders hide read articles by default, so we store the folder
			// only if it's showing read articles. It's the opposite of
			// feedsHidingReadArticles.
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

	func saveFeedsHidingReadArticles() {
		var d = feedsHidingReadArticles

		// Filter out accounts and feeds that no longer exist.
		for accountID in Array(d.keys) {
			guard let account = AccountManager.shared.existingAccount(accountID: accountID) else {
				d[accountID] = nil
				continue
			}
			d[accountID] = d[accountID]?.filter { account.existingFeed(withFeedID: $0) != nil }
		}

		AppDefaults.shared.feedsHidingReadArticles = d
	}

	func saveSmartFeedsHidingReadArticles() {
		AppDefaults.shared.smartFeedsHidingReadArticles = smartFeedsHidingReadArticles
	}
}
