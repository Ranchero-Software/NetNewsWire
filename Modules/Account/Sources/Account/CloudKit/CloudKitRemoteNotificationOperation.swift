//
//  CloudKitRemoteNotificationOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os
import RSCore
import CloudKitSync
import ActivityLog

@MainActor final class CloudKitRemoteNotificationOperation: MainThreadOperation, @unchecked Sendable {
	private weak var accountZone: CloudKitAccountZone?
	private weak var articlesZone: CloudKitArticlesZone?
	private let accountID: String
	private let accountDisplayName: String
	nonisolated(unsafe) private var userInfo: [AnyHashable: Any]
	private static let logger = cloudKitLogger

	init(accountZone: CloudKitAccountZone, articlesZone: CloudKitArticlesZone, accountID: String, accountDisplayName: String, userInfo: [AnyHashable: Any]) {
		self.accountZone = accountZone
		self.articlesZone = articlesZone
		self.accountID = accountID
		self.accountDisplayName = accountDisplayName
		self.userInfo = userInfo
		super.init(name: "CloudKitRemoteNotificationOperation")
	}

	override func run() {
		guard let accountZone, let articlesZone else {
			didComplete()
			return
		}

		Task { @MainActor in
			let activityLog = ActivityLog.shared
			let owner = ActivityOwner.account(accountID: accountID, displayName: accountDisplayName)
			let taskNumber = activityLog.nextTaskNumberString()

			let accountZoneActivityID = activityLog.createActivity(owner: owner, kind: .refreshFeedList, detail: "Receiving account changes \(taskNumber)")
			activityLog.didStart(id: accountZoneActivityID)

			Self.logger.debug("iCloud: Processing remote notification")
			await accountZone.receiveRemoteNotification(userInfo: userInfo)
			activityLog.didComplete(id: accountZoneActivityID)

			let articlesZoneActivityID = activityLog.createActivity(owner: owner, kind: .refreshArticleStatuses, detail: "Receiving article changes \(taskNumber)")
			activityLog.didStart(id: articlesZoneActivityID)
			await articlesZone.receiveRemoteNotification(userInfo: self.userInfo)
			activityLog.didComplete(id: articlesZoneActivityID)

			Self.logger.debug("iCloud: Finished processing remote notification")
			didComplete()
		}
	}
}
