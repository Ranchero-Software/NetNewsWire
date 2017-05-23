//
//  Notifications.swift
//  DataModel
//
//  Created by Brent Simmons on 9/10/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Notification.Name {
	
	public static let ArticleStatusesDidChange = Notification.Name(rawValue: "ArticleStatusesDidChange")
	public static let UnreadCountDidChange = Notification.Name(rawValue: "UnreadCountDidChangeNotification")
	public static let DataModelDidPerformBatchUpdates = Notification.Name(rawValue: "DataModelDidPerformBatchUpdatesDidPerformBatchUpdatesNotification")
	public static let AccountRefreshProgressDidChange = Notification.Name(rawValue: "AccountRefreshProgressDidChangeNotification")
}

public let articlesKey = "articles"
public let unreadCountKey = "unreadCount"
public let progressKey = "progress" //RSProgress
