//
//  Notifications.swift
//  RSCore
//
//  Created by Brent Simmons on 3/7/26.
//

import Foundation
import os

// These are all posted on the main thread.

public extension Notification.Name {
	static let lowMemory = Notification.Name("LowMemoryNotification")
	static let appDidGoToBackground = Notification.Name("AppDidGoToBackgroundNotification")
	static let appDidBecomeActive = Notification.Name("AppDidBecomeActiveNotification")
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

	public static func postAppDidBecomeActive() {
		notificationLogger.info("Posting app did become active notification.")
		NotificationCenter.default.postOnMainThread(name: .appDidBecomeActive, object: nil)
	}
}
