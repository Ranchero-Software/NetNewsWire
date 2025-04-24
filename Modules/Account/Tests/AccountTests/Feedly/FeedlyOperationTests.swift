//
//  FeedlyOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSWeb
import RSCore

class FeedlyOperationTests: XCTestCase {
	
	enum TestOperationError: Error, Equatable {
		case mockError
		case anotherMockError
	}
	
	final class TestOperation: FeedlyOperation {
		var didCallMainExpectation: XCTestExpectation?
		var mockError: Error?
		
		override func run() {
			super.run()
			// Should always call on main thread.
			XCTAssertTrue(Thread.isMainThread)
			
			didCallMainExpectation?.fulfill()
			
			if let error = mockError {
				didFinish(with: error)
			} else {
				didFinish()
			}
		}
	}
	
	final class TestDelegate: FeedlyOperationDelegate {
		
		var error: Error?
		var didFailExpectation: XCTestExpectation?
		
		func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
			didFailExpectation?.fulfill()
			self.error = error
		}
	}

    func testDoesCallMain() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		
		MainThreadOperationQueue.shared.add(testOperation)
		
		waitForExpectations(timeout: 2)
    }

	func testDoesFail() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		testOperation.mockError = TestOperationError.mockError
		
		let delegate = TestDelegate()
		delegate.didFailExpectation = expectation(description: "Operation Failed As Expected")
		
		testOperation.delegate = delegate
		
		MainThreadOperationQueue.shared.add(testOperation)
		
		waitForExpectations(timeout: 2)
		
		if let error = delegate.error as? TestOperationError {
			XCTAssertEqual(error, TestOperationError.mockError)
		} else {
			XCTFail("Expected \(TestOperationError.self) but got \(String(describing: delegate.error)).")
		}
    }
	
	func testOperationFlags() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		
		let completionExpectation = expectation(description: "Operation Completed")
		testOperation.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		

		XCTAssertFalse(testOperation.isCanceled)
		
		MainThreadOperationQueue.shared.add(testOperation)
		
		waitForExpectations(timeout: 2)
		
		XCTAssertFalse(testOperation.isCanceled)
    }
	
	func testOperationCancellationFlags() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		testOperation.didCallMainExpectation?.isInverted = true
		
		let completionExpectation = expectation(description: "Operation Completed")
		testOperation.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		XCTAssertFalse(testOperation.isCanceled)
		
		MainThreadOperationQueue.shared.add(testOperation)
		
		MainThreadOperationQueue.shared.cancelOperations([testOperation])
		
		waitForExpectations(timeout: 2)
		
		XCTAssertTrue(testOperation.isCanceled)
    }
	
	func testDependency() {
//        let testOperation = TestOperation()
//		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
//		
//		let dependencyExpectation = expectation(description: "Did Call Dependency")
//		let blockOperation = BlockOperation {
//			dependencyExpectation.fulfill()
//		}
//
//		MainThreadOperationQueue.shared.make(blockOperation, dependOn: testOperation)
//
//		//XCTAssertTrue(blockOperation.dependencies.contains(testOperation))
//		
//		MainThreadOperationQueue.shared.addOperations([testOperation, blockOperation])
//		
//		waitForExpectations(timeout: 2)
    }
}
