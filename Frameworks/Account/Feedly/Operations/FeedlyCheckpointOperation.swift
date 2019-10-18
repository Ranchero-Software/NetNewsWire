//
//  FeedlyCheckpointOperation.swift
//  Account
//
//  Created by Kiel Gillard on 18/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyCheckpointOperationDelegate: class {
	func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation)
}

/// Single responsibility is to let the delegate know an instance is executing. The semantics are up to the delegate.
final class FeedlyCheckpointOperation: FeedlyOperation {

	weak var checkpointDelegate: FeedlyCheckpointOperationDelegate?
	
	override func main() {
		defer { didFinish() }
		guard !isCancelled else {
			return
		}
		checkpointDelegate?.feedlyCheckpointOperationDidReachCheckpoint(self)
	}
}
