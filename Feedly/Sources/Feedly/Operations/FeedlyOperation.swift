//
//  FeedlyOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import Core

public protocol FeedlyOperationDelegate: AnyObject {
	@MainActor func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error)
}

/// Abstract base class for Feedly sync operations.
///
/// Normally we don’t do inheritance — but in this case
/// it’s the best option.
@MainActor open class FeedlyOperation: MainThreadOperation {

	public weak var delegate: FeedlyOperationDelegate?
	public var downloadProgress: DownloadProgress? {
		didSet {
			oldValue?.completeTask()
			downloadProgress?.addToNumberOfTasksAndRemaining(1)
		}
	}

	// MainThreadOperation
	public var isCanceled = false {
		didSet {
			if isCanceled {
				didCancel()
			}
		}
	}
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String?
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	public init() {}
	
	open func run() {
	}

	open func didFinish() {
		if !isCanceled {
			operationDelegate?.operationDidComplete(self)
		}
		downloadProgress?.completeTask()
	}

	open func didFinish(with error: Error) {
		delegate?.feedlyOperation(self, didFailWith: error)
		didFinish()
	}

	open func didCancel() {
		didFinish()
	}
}
