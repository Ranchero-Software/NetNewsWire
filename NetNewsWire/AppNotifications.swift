//
//  AppNotifications.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/30/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles

extension Notification.Name {
	static let InspectableObjectsDidChange = Notification.Name("TimelineSelectionDidChangeNotification")
	static let UserDidAddFeed = Notification.Name("UserDidAddFeedNotification")
	static let UserDidRequestSidebarSelection = Notification.Name("UserDidRequestSidebarSelectionNotification")
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
	static let author = "author"
}

