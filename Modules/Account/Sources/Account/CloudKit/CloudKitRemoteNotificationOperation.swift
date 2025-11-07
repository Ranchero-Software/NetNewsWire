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

final class CloudKitRemoteNotificationOperation: MainThreadOperation {
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "CloudKitRemoteNotificationOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var accountZone: CloudKitAccountZone?
	private weak var articlesZone: CloudKitArticlesZone?
	private var userInfo: [AnyHashable : Any]
	private static let logger = cloudKitLogger

	init(accountZone: CloudKitAccountZone, articlesZone: CloudKitArticlesZone, userInfo: [AnyHashable : Any]) {
		self.accountZone = accountZone
		self.articlesZone = articlesZone
		self.userInfo = userInfo
	}

	func run() {
		guard let accountZone = accountZone, let articlesZone = articlesZone else {
			self.operationDelegate?.operationDidComplete(self)
			return
		}

		Self.logger.debug("iCloud: Processing remote notification")

		accountZone.receiveRemoteNotification(userInfo: userInfo) {
			articlesZone.receiveRemoteNotification(userInfo: self.userInfo) {
				Self.logger.debug("iCloud: Finished processing remote notification")
				self.operationDelegate?.operationDidComplete(self)
			}
		}
	}
}
