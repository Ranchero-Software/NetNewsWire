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
		
 		articlesZone.refreshArticles() { result in
            self.logger.debug("Done refreshing article statuses.")
			switch result {
			case .success:
				self.operationDelegate?.operationDidComplete(self)
			case .failure(let error):
                self.logger.debug("Receive status error: \(error.localizedDescription, privacy: .public)")
				self.operationDelegate?.cancelOperation(self)
			}
		}
	}
	
}
