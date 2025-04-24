//
//  FeedlyOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb
import RSCore

protocol FeedlyOperationDelegate: AnyObject {
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error)
}

/// Abstract base class for Feedly sync operations.
///
/// Normally we don’t do inheritance — but in this case
/// it’s the best option.
class FeedlyOperation: MainThreadOperation {

	weak var delegate: FeedlyOperationDelegate?
	var downloadProgress: DownloadProgress? {
		didSet {
			oldValue?.completeTask()
			downloadProgress?.addToNumberOfTasksAndRemaining(1)
		}
	}

	// MainThreadOperation
	var isCanceled = false {
		didSet {
			if isCanceled {
				didCancel()
			}
		}
	}
	var id: Int?
	weak var operationDelegate: MainThreadOperationDelegate?
	var name: String?
	var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	func run() {
	}

	func didFinish() {
		if !isCanceled {
			operationDelegate?.operationDidComplete(self)
		}
		downloadProgress?.completeTask()
	}

	func didFinish(with error: Error) {
		delegate?.feedlyOperation(self, didFailWith: error)
		didFinish()
	}

	func didCancel() {
		didFinish()
	}
}
