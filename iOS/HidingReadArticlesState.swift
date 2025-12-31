//
//  HidingReadArticlesState.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 12/8/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import Account

final class HidingReadArticlesState {
	private var smartFeedsHiding = Set<String>()
	private var feedsHiding = [String: Set<String>]() // accountID: Set<feed.webFeedID>
	private var foldersShowing = [String: Set<String>]() // accountID: Set<folder.nameForDisplay>

	func copy(from stateRestorationInfo: StateRestorationInfo) {
		smartFeedsHiding = stateRestorationInfo.smartFeedsHidingReadArticles
		feedsHiding = stateRestorationInfo.feedsHidingReadArticles
		foldersShowing = stateRestorationInfo.foldersShowingReadArticles
	}
	
	func save() {
		saveSmartFeedsHiding()
		saveFeedsHiding()
		saveFoldersShowing()
	}

	func toggleHiding(for sidebarItemID: FeedIdentifier) {
		assert(canToggleHiding(for: sidebarItemID))
		if (!canToggleHiding(for: sidebarItemID)) {
			return
		}

		let hidesReadArticles = isHiding(for: sidebarItemID)
		let toggledValue = !hidesReadArticles
		saveHiding(for: sidebarItemID, hiding: toggledValue)
	}

	func isHiding(for sidebarItemID: FeedIdentifier) -> Bool {
		switch sidebarItemID {

		case .smartFeed(let id):
			if isUnreadSmartFeed(sidebarItemID) {
				return true
			}
			return smartFeedsHiding.contains(id)

		case .webFeed(let accountID, let feedID):
			var isHidingReadArticles = false
			if let feedIDs = feedsHiding[accountID] {
				isHidingReadArticles = feedIDs.contains(feedID)
			}
			return isHidingReadArticles

		case .folder(let accountID, let folderName):
			// Folders hide read articles by default, so we check if not showing read articles.
			var isHidingReadArticles = true
			if let folderNames = foldersShowing[accountID] {
				isHidingReadArticles = !folderNames.contains(folderName)
			}
			return isHidingReadArticles
		}
	}

	func canToggleHiding(for sidebarItemID: FeedIdentifier) -> Bool {
		// The only item that can't be toggled is the unread smart feed.
		!isUnreadSmartFeed(sidebarItemID)
	}
}

private extension HidingReadArticlesState {

	func isUnreadSmartFeed(_ sidebarItemID: FeedIdentifier) -> Bool {
		sidebarItemID == SmartFeedsController.shared.unreadFeed.feedID
	}

	func saveHiding(for sidebarItemID: FeedIdentifier, hiding: Bool) {
		switch sidebarItemID {

		case .smartFeed(let id):
			if isUnreadSmartFeed(sidebarItemID) {
				return
			}
			if hiding {
				smartFeedsHiding.insert(id)
			} else {
				smartFeedsHiding.remove(id)
			}
			saveSmartFeedsHiding()

		case .webFeed(let accountID, let feedID):
			if hiding {
				var feedIDs = feedsHiding[accountID] ?? Set<String>()
				feedIDs.insert(feedID)
				feedsHiding[accountID] = feedIDs
			} else {
				feedsHiding[accountID]?.remove(feedID)
			}
			saveFeedsHiding()

		case .folder(let accountID, let folderName):
			// Folders hide read articles by default, so we store the folder
			// only if it's showing read articles. It's the opposite of
			// feedsHidingReadArticles.
			if hiding {
				foldersShowing[accountID]?.remove(folderName)
			} else {
				var folderNames = foldersShowing[accountID] ?? Set<String>()
				folderNames.insert(folderName)
				foldersShowing[accountID] = folderNames
			}
			saveFoldersShowing()
		}
	}

	func saveFoldersShowing() {
		var d = foldersShowing

		// Filter out accounts and folders that no longer exist.
		for accountID in Array(d.keys) {
			guard let account = AccountManager.shared.existingAccount(with: accountID) else {
				d[accountID] = nil
				continue
			}
			d[accountID] = d[accountID]?.filter { account.existingFolder(withDisplayName: $0) != nil }
		}

		AppDefaults.shared.foldersShowingReadArticles = d
	}

	func saveFeedsHiding() {
		var d = feedsHiding

		// Filter out accounts and feeds that no longer exist.
		for accountID in Array(d.keys) {
			guard let account = AccountManager.shared.existingAccount(with: accountID) else {
				d[accountID] = nil
				continue
			}
			d[accountID] = d[accountID]?.filter { account.existingWebFeed(withWebFeedID: $0) != nil }
		}

		AppDefaults.shared.feedsHidingReadArticles = d
	}

	func saveSmartFeedsHiding() {
		AppDefaults.shared.smartFeedsHidingReadArticles = smartFeedsHiding
	}
}
