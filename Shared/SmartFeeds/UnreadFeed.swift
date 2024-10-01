//
//  UnreadFeed.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import Foundation
#endif
import Account
import Articles
import Images

// This just shows the global unread count, which appDelegate already has. Easy.

final class UnreadFeed: PseudoFeed {
	
	var account: Account? = nil

	var defaultReadFilterType: ReadFilterType {
		return .alwaysRead
	}

	var sidebarItemID: SidebarItemIdentifier? {
		return SidebarItemIdentifier.smartFeed(String(describing: UnreadFeed.self))
	}

	let nameForDisplay = NSLocalizedString("All Unread", comment: "All Unread pseudo-feed title")
	let fetchType = FetchType.unread(nil)
	
	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}

	var smallIcon: IconImage? {
		return AppAssets.unreadFeedImage
	}
	
	#if os(macOS)
	var pasteboardWriter: NSPasteboardWriting {
		return SmartFeedPasteboardWriter(smartFeed: self)
	}
	#endif
	
	@MainActor init() {

		NotificationCenter.default.addObserver(self, selector: #selector(appUnreadCountDidChange(_:)), name: .appUnreadCountDidChange, object: nil)
	}

	@objc @MainActor func appUnreadCountDidChange(_ note: Notification) {
		
		if let unreadCount = note.unreadCount {
			self.unreadCount = unreadCount
		}
	}
}

extension UnreadFeed: ArticleFetcher {
	
	// Always fetches unread articles
	func fetchArticles() async throws -> Set<Article> {

		try await fetchUnreadArticles()
	}

	func fetchUnreadArticles() async throws -> Set<Article> {

		try await AccountManager.shared.fetchArticles(fetchType: fetchType)
	}
}
