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

// This just shows the global unread count, which appDelegate already has. Easy.

final class UnreadFeed: PseudoFeed {

	let nameForDisplay = NSLocalizedString("All Unread", comment: "All Unread pseudo-feed title")

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
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

extension UnreadFeed: ArticleFetcher {

	func fetchArticles() -> Set<Article> {

		return fetchUnreadArticles()
	}

	func fetchUnreadArticles() -> Set<Article> {

		var articles = Set<Article>()
		for account in AccountManager.shared.accounts {
			articles.formUnion(account.fetchUnreadArticles())
		}
		return articles
	}
}
