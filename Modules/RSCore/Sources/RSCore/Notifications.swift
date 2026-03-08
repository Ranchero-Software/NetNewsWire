//
//  Notifications.swift
//  RSCore
//
//  Created by Brent Simmons on 3/7/26.
//

import Foundation

public extension Notification.Name {
	/// Posted when the app should free memory — on background transition
	/// and potentially on memory warnings. Always posted on the main thread.
	static let lowMemory = Notification.Name("LowMemoryNotification")
}
