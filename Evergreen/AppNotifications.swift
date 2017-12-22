//
//  AppNotifications.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/30/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import Data

extension Notification.Name {
	
	static let SidebarSelectionDidChange = Notification.Name("SidebarSelectionDidChangeNotification")
	static let TimelineSelectionDidChange = Notification.Name("TimelineSelectionDidChangeNotification")

	static let AppNavigationKeyPressed = Notification.Name("AppNavigationKeyPressedNotification")

	static let UserDidAddFeed = Notification.Name("UserDidAddFeedNotification")

	// Sent by DetailViewController when mouse hovers over link in web view.
	static let MouseDidEnterLink = Notification.Name("MouseDidEnterLinkNotification")
	static let MouseDidExitLink = Notification.Name("MouseDidExitLinkNotification")
}

typealias UserInfoDictionary = [AnyHashable: Any]

struct UserInfoKey {

	static let view = "view"
	static let article = "article"
	static let articles = "articles"
	static let navigationKeyPressed = "navigationKeyPressed"
	static let objects = "objects"
	static let feed = "feed"
	static let url = "url"
}

