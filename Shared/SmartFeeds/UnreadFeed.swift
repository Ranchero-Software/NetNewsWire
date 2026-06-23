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
import RSCore
import Account
import Articles
import ArticlesDatabase
import Images

// This just shows the global unread count, which appDelegate already has. Easy.

@MainActor final class UnreadFeed: PseudoFeed {

	var account: Account?

	public var defaultReadFilterType: ReadFilterType {
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
		Assets.Images.unreadFeed
	}

	#if os(macOS)
	var pasteboardWriter: NSPasteboardWriting {
		return SmartFeedPasteboardWriter(smartFeed: self)
	}
	#endif

	init() {

		self.unreadCount = appDelegate.unreadCount
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: appDelegate)
	}

	@objc func unreadCountDidChange(_ note: Notification) {

		assert(note.object is AppDelegate)
		unreadCount = appDelegate.unreadCount
	}
}

@MainActor extension UnreadFeed: ArticleFetcher {

	func fetchArticles() -> Set<Article> {
		fetchUnreadArticles()
	}

	func fetchArticlesAsync() async -> Set<Article> {
		await fetchUnreadArticlesAsync()
	}

	func fetchUnreadArticles() -> Set<Article> {
		AccountManager.shared.fetchArticles(fetchType)
	}

	func fetchUnreadArticlesAsync() async -> Set<Article> {
		await AccountManager.shared.fetchArticlesAsync(fetchType)
	}
}
