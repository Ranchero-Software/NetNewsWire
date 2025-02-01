//
//  ManualRefreshNotification.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/1/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

extension Notification.Name {
	static let userDidTriggerManualRefresh = Notification.Name("userDidTriggerManualRefresh")
}

// See UserInfoKey.errorHandler for the required ErrorHandler

struct ManualRefreshNotification {

	static func post(errorHandler: @escaping ErrorHandlerBlock, sender: Any?) {
		Task { @MainActor in
			let userInfo = [UserInfoKey.errorHandler: errorHandler]
			NotificationCenter.default.post(name: .userDidTriggerManualRefresh, object: sender, userInfo: userInfo)
		}
	}
}
