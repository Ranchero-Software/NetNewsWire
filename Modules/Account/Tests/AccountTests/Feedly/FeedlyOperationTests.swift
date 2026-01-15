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

@MainActor final class FeedlyOperationTests: XCTestCase {
	enum TestOperationError: Error, Equatable {
		case error1
		case error2
	}

	final class TestOperation: FeedlyOperation, @unchecked Sendable {
		var didCallMainExpectation: XCTestExpectation?
		var mockError: Error?

		@MainActor override func run() {
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

		FeedlyMainThreadOperationQueue.shared.add(testOperation)

		waitForExpectations(timeout: 2)
    }

	func testDoesFail() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		testOperation.mockError = TestOperationError.error1

		let delegate = TestDelegate()
		delegate.didFailExpectation = expectation(description: "Operation Failed As Expected")

		testOperation.delegate = delegate

		FeedlyMainThreadOperationQueue.shared.add(testOperation)

		waitForExpectations(timeout: 2)

		if let error = delegate.error as? TestOperationError {
			XCTAssertEqual(error, TestOperationError.error1)
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

		FeedlyMainThreadOperationQueue.shared.add(testOperation)

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

		FeedlyMainThreadOperationQueue.shared.add(testOperation)
		testOperation.cancel()

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
//		FeedlyMainThreadOperationQueue.shared.make(blockOperation, dependOn: testOperation)
//
//		//XCTAssertTrue(blockOperation.dependencies.contains(testOperation))
//		
//		FeedlyMainThreadOperationQueue.shared.addOperations([testOperation, blockOperation])
//		
//		waitForExpectations(timeout: 2)
    }
}
