//
//  NotificationCenter+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 11/9/25.
//

import Foundation

public extension NotificationCenter {

	func postOnMainThread(name: Notification.Name, object: Any?, userInfo: [AnyHashable : Any]? = nil) {
		Task { @MainActor in
			NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
		}
	}
}
