//
//  CloudKitRemoteNotificationOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import CloudKitSync

@MainActor final class CloudKitRemoteNotificationOperation: MainThreadOperation, @unchecked Sendable {
	private weak var accountZone: CloudKitAccountZone?
	private weak var articlesZone: CloudKitArticlesZone?
	nonisolated(unsafe) private var userInfo: [AnyHashable: Any]
	private static let logger = cloudKitLogger

	init(accountZone: CloudKitAccountZone, articlesZone: CloudKitArticlesZone, userInfo: [AnyHashable: Any]) {
		self.accountZone = accountZone
		self.articlesZone = articlesZone
		self.userInfo = userInfo
		super.init(name: "CloudKitRemoteNotificationOperation")
	}

	override func run() {
		guard let accountZone, let articlesZone else {
			didComplete()
			return
		}

		Task { @MainActor in
			Self.logger.debug("iCloud: Processing remote notification")
			await accountZone.receiveRemoteNotification(userInfo: userInfo)
			await articlesZone.receiveRemoteNotification(userInfo: self.userInfo)

			Self.logger.debug("iCloud: Finished processing remote notification")
			didComplete()
		}
	}
}
