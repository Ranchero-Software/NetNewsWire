//
//  CloudKitReceiveStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os.log
import RSCore
import CloudKitSync

final class CloudKitReceiveStatusOperation: MainThreadOperation {
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "CloudKitReceiveStatusOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var articlesZone: CloudKitArticlesZone?
	private static let logger = cloudKitLogger

	init(articlesZone: CloudKitArticlesZone) {
		self.articlesZone = articlesZone
	}

	func run() {
		guard let articlesZone else {
			self.operationDelegate?.operationDidComplete(self)
			return
		}

		Self.logger.debug("iCloud: Refreshing article statuses")

 		articlesZone.refreshArticles() { result in
			Self.logger.debug("iCloud: Finished refreshing article statuses")
			switch result {
			case .success:
				self.operationDelegate?.operationDidComplete(self)
			case .failure(let error):
				Self.logger.error("iCloud: Receive status error: \(error.localizedDescription)")
				self.operationDelegate?.cancelOperation(self)
			}
		}
	}
}
