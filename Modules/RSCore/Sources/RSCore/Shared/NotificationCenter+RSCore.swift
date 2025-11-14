//
//  NotificationCenter+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 11/9/25.
//

import Foundation

nonisolated public extension NotificationCenter {

	func postOnMainThread(name: Notification.Name, object: Any?, userInfo: [AnyHashable : Any]? = nil) {
		nonisolated(unsafe) let capturedObject = object
		nonisolated(unsafe) let capturedUserInfo = userInfo
		Task { @MainActor in
			NotificationCenter.default.post(name: name, object: capturedObject, userInfo: capturedUserInfo)
		}
	}
}
