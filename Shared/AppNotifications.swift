//
//  AppNotifications.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/30/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Articles

extension Notification.Name {
	
	static let appUnreadCountDidChange = Notification.Name("AppUnreadCountDidChangeNotification")
	static let InspectableObjectsDidChange = Notification.Name("InspectableObjectsDidChangeNotification")
	static let UserDidAddFeed = Notification.Name("UserDidAddFeedNotification")
	static let LaunchedFromExternalAction = Notification.Name("LaunchedFromExternalAction")

	#if !MAC_APP_STORE
		static let WebInspectorEnabledDidChange = Notification.Name("WebInspectorEnabledDidChange")
	#endif
}

struct AppNotificationUserInfoKey {

	static let unreadCount = "unreadCount"
}

extension Notification {

	var unreadCount: Int? {
		guard name == .appUnreadCountDidChange else {
			assertionFailure("This is to be used only with the .appUnreadCountDidChange notification")
			return nil
		}
		guard let userInfo, let count = userInfo[AppNotificationUserInfoKey.unreadCount] as? Int else {
			assertionFailure("Missing unread count in notification")
			return nil
		}
		return count
	}
}

struct AppNotification {

	static func postAppUnreadCountDidChange(from: Any, unreadCount: Int) {
		var userInfo = [AnyHashable: Any]()
		userInfo[AppNotificationUserInfoKey.unreadCount] = unreadCount
		NotificationCenter.default.post(name: .appUnreadCountDidChange, object: from, userInfo: userInfo)
	}
}
