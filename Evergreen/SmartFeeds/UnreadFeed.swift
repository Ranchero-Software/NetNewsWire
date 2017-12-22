//
//  UnreadFeed.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

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

	init() {

		self.unreadCount = appDelegate.unreadCount
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: appDelegate)
	}

	@objc func unreadCountDidChange(_ note: Notification) {

		assert(note.object is AppDelegate)
		unreadCount = appDelegate.unreadCount
	}
}
