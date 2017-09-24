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
}

extension Notification {

	var appInfo: AppInfo? {
		get {
			return AppInfo.pullFromUserInfo(userInfo)
		}
	}
}

typealias UserInfoDictionary = [AnyHashable: Any]

final class AppInfo {

	// These are things commonly passed around in Evergreen notifications.
	// Rather than setting these things using strings, we have a single AppInfo class
	// that the userInfo dictionary may contain.

	var view: NSView?
	var article: Article?
	var articles: Set<Article>?
	var navigationKey: Int?
	var objects: [AnyObject]?

	static let appInfoKey = "appInfo"

	var userInfo: UserInfoDictionary {
		get {
			return [AppInfo.appInfoKey: self] as UserInfoDictionary
		}
	}

	static func pullFromUserInfo(_ userInfo: UserInfoDictionary?) -> AppInfo? {

		return userInfo?[appInfoKey] as? AppInfo
	}
}


