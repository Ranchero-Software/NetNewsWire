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

class CloudKitReceiveStatusOperation: MainThreadOperation {
	
	private var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")

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
		
		os_log(.debug, log: log, "Refreshing article statuses...")
		
 		articlesZone.refreshArticles() { result in
			os_log(.debug, log: self.log, "Done refreshing article statuses.")
			switch result {
			case .success:
				self.operationDelegate?.operationDidComplete(self)
			case .failure(let error):
				os_log(.error, log: self.log, "Receive status error: %@.", error.localizedDescription)
				self.operationDelegate?.cancelOperation(self)
			}
		}
	}
	
}
