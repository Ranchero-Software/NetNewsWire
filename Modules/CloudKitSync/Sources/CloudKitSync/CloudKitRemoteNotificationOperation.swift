//
//  CloudKitRemoteNotificationOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import Core

@MainActor public final class CloudKitRemoteNotificationOperation: MainThreadOperation {

	private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "CloudKitRemoteNotificationOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var accountZone: CloudKitAccountZone?
	private weak var articlesZone: CloudKitArticlesZone?
	private var userInfo: [AnyHashable : Any]
	
	public init(accountZone: CloudKitAccountZone, articlesZone: CloudKitArticlesZone, userInfo: [AnyHashable : Any]) {
		self.accountZone = accountZone
		self.articlesZone = articlesZone
		self.userInfo = userInfo
	}

	@MainActor public func run() {
		guard let accountZone = accountZone, let articlesZone = articlesZone else {
			self.operationDelegate?.operationDidComplete(self)
			return
		}

		os_log(.debug, log: log, "Processing remote notification...")

		Task { @MainActor in

			await accountZone.receiveRemoteNotification(userInfo: userInfo)
			await articlesZone.receiveRemoteNotification(userInfo: self.userInfo)
			
			os_log(.debug, log: self.log, "Done processing remote notification.")
			self.operationDelegate?.operationDidComplete(self)
		}
	}
}
