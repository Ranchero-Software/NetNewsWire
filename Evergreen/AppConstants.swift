//
//  AppConstants.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/30/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

extension Notification.Name {
	
	static let SidebarSelectionDidChange = Notification.Name("SidebarSelectionDidChangeNotification")
	static let TimelineSelectionDidChange = Notification.Name("TimelineSelectionDidChangeNotification")

	static let AppNavigationKeyPressed = Notification.Name("AppNavigationKeyPressedNotification")
}

let viewKey = "view"
let nodeKey = "node"
let objectsKey = "objects"
let articleKey = "article"

let articlesKey = "articles"
let articleStatusKey = "statusKey"

let appNavigationKey = "keyKey"
