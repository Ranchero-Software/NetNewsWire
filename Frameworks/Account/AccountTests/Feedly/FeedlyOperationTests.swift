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

class FeedlyOperationTests: XCTestCase {
	
	enum TestOperationError: Error, Equatable {
		case mockError
		case anotherMockError
	}
	
	final class TestOperation: FeedlyOperation {
		var didCallMainExpectation: XCTestExpectation?
		var mockError: Error?
		
		override func main() {
			// Should always call on main thread.
			XCTAssertTrue(Thread.isMainThread)
			
			didCallMainExpectation?.fulfill()
			
			if let error = mockError {
				didFinish(error)
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
		
		OperationQueue.main.addOperation(testOperation)
		
		waitForExpectations(timeout: 2)
    }

	func testDoesFail() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		testOperation.mockError = TestOperationError.mockError
		
		let delegate = TestDelegate()
		delegate.didFailExpectation = expectation(description: "Operation Failed As Expected")
		
		testOperation.delegate = delegate
		
		OperationQueue.main.addOperation(testOperation)
		
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
		testOperation.completionBlock = {
			completionExpectation.fulfill()
		}
		
		XCTAssertTrue(testOperation.isReady)
		XCTAssertFalse(testOperation.isFinished)
		XCTAssertFalse(testOperation.isExecuting)
		XCTAssertFalse(testOperation.isCancelled)
		
		OperationQueue.main.addOperation(testOperation)
		
		waitForExpectations(timeout: 2)
		
		XCTAssertTrue(testOperation.isReady)
		XCTAssertTrue(testOperation.isFinished)
		XCTAssertFalse(testOperation.isExecuting)
		XCTAssertFalse(testOperation.isCancelled)
    }
	
	func testOperationCancellationFlags() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		testOperation.didCallMainExpectation?.isInverted = true
		
		let completionExpectation = expectation(description: "Operation Completed")
		testOperation.completionBlock = {
			completionExpectation.fulfill()
		}
		
		XCTAssertTrue(testOperation.isReady)
		XCTAssertFalse(testOperation.isFinished)
		XCTAssertFalse(testOperation.isExecuting)
		XCTAssertFalse(testOperation.isCancelled)
		
		OperationQueue.main.addOperation(testOperation)
		
		testOperation.cancel()
		
		waitForExpectations(timeout: 2)
		
		XCTAssertTrue(testOperation.isReady)
		XCTAssertTrue(testOperation.isFinished)
		XCTAssertFalse(testOperation.isExecuting)
		XCTAssertTrue(testOperation.isCancelled)
    }
	
	func testDependency() {
        let testOperation = TestOperation()
		testOperation.didCallMainExpectation = expectation(description: "Did Call Main")
		
		let dependencyExpectation = expectation(description: "Did Call Dependency")
		let blockOperation = BlockOperation {
			dependencyExpectation.fulfill()
		}
		
		blockOperation.addDependency(testOperation)
		
		XCTAssertTrue(blockOperation.dependencies.contains(testOperation))
		
		OperationQueue.main.addOperations([testOperation, blockOperation], waitUntilFinished: false)
		
		waitForExpectations(timeout: 2)
    }
	
	func testProgressReporting() {
		let progress = DownloadProgress(numberOfTasks: 0)
		let didChangeExpectation = expectation(forNotification: .DownloadProgressDidChange, object: progress)
		// This number is the number of times breakpoints on calls to DownloadProgress.postDidChangeNotification is hit.
		didChangeExpectation.expectedFulfillmentCount = 4
		didChangeExpectation.assertForOverFulfill = true
		
        let testOperation = TestOperation()
		
		testOperation.downloadProgress = progress
		XCTAssertTrue(progress.numberRemaining == 1)
		
		testOperation.downloadProgress = nil
		XCTAssertTrue(progress.numberRemaining == 0)
		
		waitForExpectations(timeout: 2)
	}
	
	func testProgressReportingOnCancel() {
		let progress = DownloadProgress(numberOfTasks: 0)
		let didChangeExpectation = expectation(forNotification: .DownloadProgressDidChange, object: progress)
		// This number is the number of times breakpoints on calls to DownloadProgress.postDidChangeNotification is hit.
		didChangeExpectation.expectedFulfillmentCount = 4
		didChangeExpectation.assertForOverFulfill = true
		
		let testOperation = TestOperation()
		testOperation.downloadProgress = progress
		
		let completionExpectation = expectation(description: "Operation Completed")
		testOperation.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(testOperation)
		
		XCTAssertTrue(progress.numberRemaining == 1)
		testOperation.cancel()
		XCTAssertTrue(progress.numberRemaining == 1)
		
		waitForExpectations(timeout: 2)
		
		XCTAssertTrue(progress.numberRemaining == 0)
    }
	
	func testDoesProgressReportingOnSuccess() {
		let progress = DownloadProgress(numberOfTasks: 0)
		let didChangeExpectation = expectation(forNotification: .DownloadProgressDidChange, object: progress)
		// This number is the number of times breakpoints on calls to DownloadProgress.postDidChangeNotification is hit.
		didChangeExpectation.expectedFulfillmentCount = 4
		didChangeExpectation.assertForOverFulfill = true
		
		let testOperation = TestOperation()
		testOperation.downloadProgress = progress
		
		let completionExpectation = expectation(description: "Operation Completed")
		testOperation.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(testOperation)
		
		XCTAssertTrue(progress.numberRemaining == 1)
		
		waitForExpectations(timeout: 2)
		
		XCTAssertTrue(progress.numberRemaining == 0)
    }
	
	func testProgressReportingOnFailure() {
		let progress = DownloadProgress(numberOfTasks: 0)
		let didChangeExpectation = expectation(forNotification: .DownloadProgressDidChange, object: progress)
		// This number is the number of times breakpoints on calls to DownloadProgress.postDidChangeNotification is hit.
		didChangeExpectation.expectedFulfillmentCount = 4
		didChangeExpectation.assertForOverFulfill = true
		
		let testOperation = TestOperation()
		testOperation.mockError = TestOperationError.mockError
		testOperation.downloadProgress = progress
		
		let completionExpectation = expectation(description: "Operation Completed")
		testOperation.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(testOperation)
		
		XCTAssertTrue(progress.numberRemaining == 1)
		
		waitForExpectations(timeout: 2)
		
		XCTAssertTrue(progress.numberRemaining == 0)
    }
}
