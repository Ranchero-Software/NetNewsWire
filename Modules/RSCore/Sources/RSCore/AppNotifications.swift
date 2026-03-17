//
//  Notifications.swift
//  RSCore
//
//  Created by Brent Simmons on 3/7/26.
//

import Foundation
import os

public extension Notification.Name {

	/// Posted on actual low memory condition. Main thread.
	static let lowMemory = Notification.Name("LowMemoryNotification")

	/// Posted when the app goes to background. Main thread.
	static let appDidGoToBackground = Notification.Name("AppDidGoToBackgroundNotification")
}

public struct AppNotification {

	private static let notificationLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppNotification")

	public static func postLowMemory() {
		notificationLogger.info("Posting low memory notification.")
		NotificationCenter.default.postOnMainThread(name: .lowMemory, object: nil)
	}

	public static func postAppDidGoToBackground() {
		notificationLogger.info("Posting app did go to background notification.")
		NotificationCenter.default.postOnMainThread(name: .appDidGoToBackground, object: nil)
	}
}
