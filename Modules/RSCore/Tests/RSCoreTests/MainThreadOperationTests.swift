//
//  MainThreadOperationTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 1/17/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSCore

@MainActor final class MainThreadOperationTests: XCTestCase {

	func testSingleOperation() {
		let queue = MainThreadOperationQueue()
		let singleOperationDidRunExpectation = expectation(description: "singleOperationDidRun")
		let operation = MainThreadBlockOperation {
			singleOperationDidRunExpectation.fulfill()
		}

		queue.add(operation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testOperationAndDependency() {
		let queue = MainThreadOperationQueue()
		nonisolated(unsafe)var operationIndex = 0

		let parentOperationExpectation = expectation(description: "parentOperation")
		let parentOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 0)
			operationIndex += 1
			parentOperationExpectation.fulfill()
		}

		let childOperationExpectation = expectation(description: "childOperation")
		let childOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 1)
			operationIndex += 1
			childOperationExpectation.fulfill()
		}

		childOperation.addDependency(parentOperation)
		queue.add(parentOperation)
		queue.add(childOperation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testOperationAndDependencyAddedOutOfOrder() {
		let queue = MainThreadOperationQueue()
		nonisolated(unsafe) var operationIndex = 0

		let parentOperationExpectation = expectation(description: "parentOperation")
		let parentOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 0)
			operationIndex += 1
			parentOperationExpectation.fulfill()
		}
		let childOperationExpectation = expectation(description: "childOperation")
		let childOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 1)
			operationIndex += 1
			childOperationExpectation.fulfill()
		}

		childOperation.addDependency(parentOperation)
		queue.add(childOperation)
		queue.add(parentOperation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testOperationAndTwoDependenciesAddedOutOfOrder() {
		let queue = MainThreadOperationQueue()
		nonisolated(unsafe) var operationIndex = 0

		let parentOperationExpectation = expectation(description: "parentOperation")
		let parentOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 0)
			operationIndex += 1
			parentOperationExpectation.fulfill()
		}

		let childOperationExpectation = expectation(description: "childOperation")
		let childOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 1)
			operationIndex += 1
			childOperationExpectation.fulfill()
		}

		let childOperationExpectation2 = expectation(description: "childOperation2")
		let childOperation2 = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 2)
			operationIndex += 1
			childOperationExpectation2.fulfill()
		}

		childOperation.addDependency(parentOperation)
		childOperation2.addDependency(parentOperation)
		queue.add(childOperation)
		queue.add(childOperation2)
		queue.add(parentOperation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testChildOperationWithTwoDependencies() {
		let queue = MainThreadOperationQueue()
		nonisolated(unsafe) var operationIndex = 0

		let parentOperationExpectation = expectation(description: "parentOperation")
		let parentOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 0)
			operationIndex += 1
			parentOperationExpectation.fulfill()
		}

		let parentOperationExpectation2 = expectation(description: "parentOperation2")
		let parentOperation2 = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 1)
			operationIndex += 1
			parentOperationExpectation2.fulfill()
		}

		let childOperationExpectation = expectation(description: "childOperation")
		let childOperation = MainThreadBlockOperation {
			XCTAssertTrue(operationIndex == 2)
			operationIndex += 1
			childOperationExpectation.fulfill()
		}

		childOperation.addDependency(parentOperation)
		childOperation.addDependency(parentOperation2)

		queue.add(childOperation)
		queue.add(parentOperation)
		queue.add(parentOperation2)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testAddingManyOperations() {
		let queue = MainThreadOperationQueue()
		let operationsCount = 1000
		nonisolated(unsafe) var operationIndex = 0
		var operations = [MainThreadBlockOperation]()

		for i in 0..<operationsCount {
			let operationExpectation = expectation(description: "Operation \(i)")
			let operation = MainThreadBlockOperation {
				XCTAssertTrue(operationIndex == i)
				operationIndex += 1
				operationExpectation.fulfill()
			}
			operations.append(operation)
		}

		queue.add(operations)
		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testAddingManyOperationsAndCancelingManyOperations() {
		let queue = MainThreadOperationQueue()
		let operationsCount = 1000
		var operations = [MainThreadBlockOperation]()

		for _ in 0..<operationsCount {
			let operation = MainThreadBlockOperation {
				XCTAssertTrue(false)
			}
			operations.append(operation)
		}

		queue.add(operations)
		queue.cancel(operations)
		XCTAssertEqual(queue.pendingOperationsCount, 0)
	}

	func testAddingManyOperationsWithCompletionBlocks() {
		let queue = MainThreadOperationQueue()
		let operationsCount = 100
		nonisolated(unsafe) var operationIndex = 0
		var operations = [MainThreadBlockOperation]()

		for i in 0..<operationsCount {
			let operationRunExpectation = expectation(description: "Operation \(i)")
			let operation = MainThreadBlockOperation {
				XCTAssertEqual(operationIndex, i)
				operationRunExpectation.fulfill()
			}

			let operationCompletionBlockExpectation = expectation(description: "Operation Completion \(i)")
			operation.completionBlock = { completedOperation in
				XCTAssertEqual(operation, completedOperation)
				XCTAssertEqual(operationIndex, i)
				operationIndex += 1
				operationCompletionBlockExpectation.fulfill()
			}
			operations.append(operation)
		}

		queue.add(operations)
		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertEqual(queue.pendingOperationsCount, 0)
	}

	func testCancellingOperationsWithName() {
		let queue = MainThreadOperationQueue()
		queue.suspend()

		let operationsCount = 100
		for i in 0..<operationsCount {
			let operation = MainThreadBlockOperation(name: "\(i)") {}
			queue.add(operation)
			let operation2 = MainThreadBlockOperation(name: "foo") {}
			queue.add(operation2)
		}

		queue.resume()
		queue.cancel(named: "33")
		queue.cancel(named: "99")
		queue.cancel(named: "654")
		queue.cancel(named: "foo")
		XCTAssert(queue.pendingOperationsCount == 98)

		queue.cancelAll()
		XCTAssert(queue.pendingOperationsCount == 0)
	}
}
