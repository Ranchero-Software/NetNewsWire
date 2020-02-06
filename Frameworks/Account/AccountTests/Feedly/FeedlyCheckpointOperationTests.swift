//
//  FeedlyCheckpointOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 25/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSCore

class FeedlyCheckpointOperationTests: XCTestCase {
	
	class TestDelegate: FeedlyCheckpointOperationDelegate {
		
		var didReachCheckpointExpectation: XCTestExpectation?
		
		func feedlyCheckpointOperationDidReachCheckpoint(_ operation: FeedlyCheckpointOperation) {
			didReachCheckpointExpectation?.fulfill()
		}
	}
	
	func testCallback() {
		let delegate = TestDelegate()
		delegate.didReachCheckpointExpectation = expectation(description: "Did Reach Checkpoint")
		
		let operation = FeedlyCheckpointOperation()
		operation.checkpointDelegate = delegate
		
		let didFinishExpectation = expectation(description: "Did Finish")
		operation.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(operation)
		
		waitForExpectations(timeout: 2)
	}
	
	func testCancellation() {
		let didReachCheckpointExpectation = expectation(description: "Did Reach Checkpoint")
		didReachCheckpointExpectation.isInverted = true
		
		let delegate = TestDelegate()
		delegate.didReachCheckpointExpectation = didReachCheckpointExpectation
		
		let operation = FeedlyCheckpointOperation()
		operation.checkpointDelegate = delegate
		
		let didFinishExpectation = expectation(description: "Did Finish")
		operation.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(operation)
		
		MainThreadOperationQueue.shared.cancelOperations([operation])
		
		waitForExpectations(timeout: 1)
	}
}
