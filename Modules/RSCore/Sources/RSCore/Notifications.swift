//
//  Notifications.swift
//  RSCore
//
//  Created by Brent Simmons on 3/7/26.
//

import Foundation
import os

public extension Notification.Name {
	/// Posted when the app should free memory — on background transition
	/// and potentially on memory warnings. Always posted on the main thread.
	static let lowMemory = Notification.Name("LowMemoryNotification")
}

private let lowMemoryLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "LowMemory")

public func postLowMemoryNotification() {
	if Thread.isMainThread {
		lowMemoryLogger.info("Posting low memory notification")
		NotificationCenter.default.post(name: .lowMemory, object: nil)
	} else {
		Task { @MainActor in
			lowMemoryLogger.info("Posting low memory notification")
			NotificationCenter.default.post(name: .lowMemory, object: nil)
		}
	}
}
