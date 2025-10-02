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

final class CloudKitRemoteNotificationOperation: MainThreadOperation {

	static private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKitRemoteNotificationOperation")

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "CloudKitRemoteNotificationOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var accountZone: CloudKitAccountZone?
	private weak var articlesZone: CloudKitArticlesZone?
	private var userInfo: [AnyHashable : Any]

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
