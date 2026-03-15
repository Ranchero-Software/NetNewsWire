//
//  Notifications.swift
//  RSCore
//
//  Created by Brent Simmons on 3/7/26.
//

import Foundation
import os

public extension Notification.Name {

	/// Posted on actual low memory condition. Posted on main thread.
	static let lowMemory = Notification.Name("LowMemoryNotification")

	/// Posted when the app goes to background. Posted on main thread.
	static let appDidGoToBackground = Notification.Name("AppDidGoToBackgroundNotification")
}

private let notificationLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Notifications.swift")

public func postLowMemoryNotification() {
	NotificationCenter.default.postOnMainThread(name: .lowMemory, object: nil)
}

public func postAppDidGoToBackgroundNotification() {
	if Thread.isMainThread {
		lowMemoryLogger.info("Posting app did go to background notification")
		NotificationCenter.default.post(name: .appDidGoToBackground, object: nil)
	} else {
		Task { @MainActor in
			lowMemoryLogger.info("Posting app did go to background notification")
			NotificationCenter.default.post(name: .appDidGoToBackground, object: nil)
		}
	}
}
