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
	@MainActor func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error)
}

/// Abstract base class for Feedly sync operations.
///
/// Normally we don’t do inheritance — but in this case
/// it’s the best option.
open class FeedlyOperation: MainThreadOperation, @unchecked Sendable {
	weak var delegate: FeedlyOperationDelegate?
	var error: Error?
	var downloadProgress: DownloadProgress? {
		didSet {
			oldValue?.completeTask()
			downloadProgress?.addTask()
		}
	}

	nonisolated func didComplete(with error: Error) {
		if Thread.isMainThread {
			MainActor.assumeIsolated {
				self.error = error
				didComplete()
			}
		} else {
			Task { @MainActor in
				didComplete(with: error)
			}
		}
	}
	
	@MainActor open override func noteDidComplete() {
		downloadProgress?.completeTask()
		if let error {
			delegate?.feedlyOperation(self, didFailWith: error)
		}
		super.noteDidComplete()
	}
}
