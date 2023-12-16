//
//  CloudKitReceiveStatusOperation.swift
//  Account
//
//  Created by Maurice Parker on 5/2/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

class CloudKitReceiveStatusOperation: MainThreadOperation, Logging {
	
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "CloudKitReceiveStatusOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private weak var articlesZone: CloudKitArticlesZone?
	
	init(articlesZone: CloudKitArticlesZone) {
		self.articlesZone = articlesZone
	}
	
	func run() {
		guard let articlesZone = articlesZone else {
			self.operationDelegate?.operationDidComplete(self)
			return
		}
		
        logger.debug("Refreshing article statuses...")
		
		Task { @MainActor in
			do {
				try await articlesZone.fetchChangesInZone()
				self.logger.debug("Done refreshing article statuses.")
				self.operationDelegate?.operationDidComplete(self)
			} catch {
				self.logger.error("Receive status error: \(error.localizedDescription, privacy: .public)")
				self.operationDelegate?.cancelOperation(self)
			}
		}
	}
}
