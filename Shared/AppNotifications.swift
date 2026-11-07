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
	static let InspectableObjectsDidChange = Notification.Name("TimelineSelectionDidChangeNotification")
	static let UserDidAddFeed = Notification.Name("UserDidAddFeedNotification")
	static let WebInspectorEnabledDidChange = Notification.Name("WebInspectorEnabledDidChange")
	static let sidebarShowsIconsDidChange = Notification.Name("SidebarShowsIconsDidChangeNotification")
	static let sidebarSmartFeedsVisibilityDidChange = Notification.Name("SidebarSmartFeedsVisibilityDidChangeNotification")
	static let timelineIconSizeDidChange = Notification.Name("TimelineIconSizeDidChangeNotification")
	static let timelineNumberOfLinesDidChange = Notification.Name("TimelineNumberOfLinesDidChangeNotification")
}
