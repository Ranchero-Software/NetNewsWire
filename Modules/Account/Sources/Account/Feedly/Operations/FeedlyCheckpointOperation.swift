//
//  FeedlyCheckpointOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyCheckpointOperationDelegate: AnyObject {
	@MainActor func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation)
}

/// Let the delegate know an instance is executing. The semantics are up to the delegate.
final class FeedlyCheckpointOperation: FeedlyOperation, @unchecked Sendable {
	weak var checkpointDelegate: FeedlyCheckpointOperationDelegate?

	@MainActor override func run() {
		checkpointDelegate?.feedlyCheckpointOperationDidReachCheckpoint(self)
		didComplete()
	}
}
