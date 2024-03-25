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
import ArticlesDatabase

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

		self.unreadCount = appDelegate.unreadCount
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: appDelegate)
	}

	@objc @MainActor func unreadCountDidChange(_ note: Notification) {

		assert(note.object is AppDelegate)
		unreadCount = appDelegate.unreadCount
	}
}

extension UnreadFeed: ArticleFetcher {
	
	// Always fetches unread articles
	func fetchArticles() async throws -> Set<Article> {

		try await fetchUnreadArticles()
	}

	func fetchArticlesAsync(_ completion: @escaping ArticleSetResultBlock) {

		AccountManager.shared.fetchArticlesAsync(fetchType, completion)
	}

	func fetchUnreadArticles() async throws -> Set<Article> {

		try await AccountManager.shared.fetchArticles(fetchType: fetchType)
	}
}
