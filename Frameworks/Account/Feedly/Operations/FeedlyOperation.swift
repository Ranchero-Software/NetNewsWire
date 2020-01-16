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

protocol FeedlyOperationDelegate: class {
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error)
}

/// Abstract class common to all the tasks required to ingest content from Feedly into NetNewsWire.
/// Each task should try to have a single responsibility so they can be easily composed with others.
class FeedlyOperation: MainThreadOperation {

	weak var delegate: FeedlyOperationDelegate?

	// MainThreadOperationDelegate
	var isCanceled = false {
		didSet {
			if isCanceled {
				cancel()
			}
		}
	}
	var id: Int?
	weak var operationDelegate: MainThreadOperationDelegate?
	var completionBlock: FeedlyOperation.MainThreadOperationCompletionBlock?
	var name: String?

	var isExecuting = false
	var isFinished = false

	var downloadProgress: DownloadProgress? {
		didSet {
			guard downloadProgress == nil || !isExecuting else {
				fatalError("\(\FeedlyOperation.downloadProgress) was set to late. Set before operation starts executing.")
			}
			oldValue?.completeTask()
			downloadProgress?.addToNumberOfTasksAndRemaining(1)
		}
	}

	// Override this. Call super.run() first in the overridden method.
	func run() {
		isExecuting = true
	}

	// Called when isCanceled is set to true. Useful to override.
	func cancel() {
		didFinish()
	}

	func didFinish() {
		precondition(Thread.isMainThread)
		isExecuting = false
		isFinished = true
		downloadProgress = nil
		if !isCanceled {
			operationDelegate?.operationDidComplete(self)
		}
	}
	
	func didFinish(_ error: Error) {
		delegate?.feedlyOperation(self, didFailWith: error)
		didFinish()
	}
}
