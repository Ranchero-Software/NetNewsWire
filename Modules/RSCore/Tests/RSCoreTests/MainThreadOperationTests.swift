//
//  MainThreadOperationTests.swift
//  RSCoreTests
//
//  Created by Brent Simmons on 1/17/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import RSCore

class MainThreadOperationTests: XCTestCase {

	func testSingleOperation() {
		let queue = MainThreadOperationQueue()
		var operationDidRun = false
		let singleOperationDidRunExpectation = expectation(description: "singleOperationDidRun")
		let operation = MainThreadBlockOperation {
			operationDidRun = true
			XCTAssertTrue(operationDidRun)
			singleOperationDidRunExpectation.fulfill()
		}
		queue.add(operation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testOperationAndDependency() {
		let queue = MainThreadOperationQueue()
		var operationIndex = 0

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

		queue.make(childOperation, dependOn: parentOperation)
		queue.add(parentOperation)
		queue.add(childOperation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testOperationAndDependencyAddedOutOfOrder() {
		let queue = MainThreadOperationQueue()
		var operationIndex = 0

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

		queue.make(childOperation, dependOn: parentOperation)
		queue.add(childOperation)
		queue.add(parentOperation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testOperationAndTwoDependenciesAddedOutOfOrder() {
		let queue = MainThreadOperationQueue()
		var operationIndex = 0

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

		queue.make(childOperation, dependOn: parentOperation)
		queue.make(childOperation2, dependOn: parentOperation)
		queue.add(childOperation)
		queue.add(childOperation2)
		queue.add(parentOperation)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testChildOperationWithTwoDependencies() {
		let queue = MainThreadOperationQueue()
		var operationIndex = 0

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

		queue.make(childOperation, dependOn: parentOperation)
		queue.make(childOperation, dependOn: parentOperation2)
		queue.add(childOperation)
		queue.add(parentOperation)
		queue.add(parentOperation2)

		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testAddingManyOperations() {
		let queue = MainThreadOperationQueue()
		let operationsCount = 1000
		var operationIndex = 0
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

		queue.addOperations(operations)
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

		queue.addOperations(operations)
		queue.cancelOperations(operations)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}

	func testAddingManyOperationsWithCompletionBlocks() {
		let queue = MainThreadOperationQueue()
		let operationsCount = 100
		var operationIndex = 0
		var operations = [MainThreadBlockOperation]()

		for i in 0..<operationsCount {
			let operationExpectation = expectation(description: "Operation \(i)")
			let operationCompletionBlockExpectation = expectation(description: "Operation Completion \(i)")
			let operation = MainThreadBlockOperation {
				XCTAssertTrue(operationIndex == i)
				operationExpectation.fulfill()
			}
			operation.completionBlock = { completedOperation in
				XCTAssert(operation === completedOperation)
				XCTAssertTrue(operationIndex == i)
				operationIndex += 1
				operationCompletionBlockExpectation.fulfill()
			}
			operations.append(operation)
		}

		queue.addOperations(operations)
		waitForExpectations(timeout: 1.0, handler: nil)
		XCTAssertTrue(queue.pendingOperationsCount == 0)
	}
    
    func testCancelingDisownsOperation() {
        
		final class SlowFinishingOperation: MainThreadOperation {

			let didCancelExpectation: XCTestExpectation

			// MainThreadOperation
            var isCanceled = false {
                didSet {
                    if isCanceled {
                        didCancelExpectation.fulfill()
                    }
                }
            }
			var id: Int?
            var operationDelegate: MainThreadOperationDelegate?
            var name: String?
            var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?
            
            var didStartRunBlock: (() -> ())?

			init(didCancelExpectation: XCTestExpectation) {
				self.didCancelExpectation = didCancelExpectation
			}

            func run() {
                guard let block = didStartRunBlock else {
                    XCTFail("Unable to test cancellation of running operation.")
                    return
                }
                block()
                DispatchQueue.main.async { [weak self] in
					if let self = self {
						XCTAssert(false, "This code should not be executed.")
						self.operationDelegate?.operationDidComplete(self)
					}
                }
            }
        }
        
        let queue = MainThreadOperationQueue()
		let didCancelExpectation = expectation(description: "Did Cancel Operation")
		let completionBlockDidRunExpectation = expectation(description: "Completion Block Did Run")

		// Using an Optional allows us to control this scope's ownership of the operation.
        var operation: SlowFinishingOperation? = {
            let operation = SlowFinishingOperation(didCancelExpectation: didCancelExpectation)
			operation.didStartRunBlock = { [weak operation] in
                guard let operation = operation else {
                    XCTFail("Could not cancel slow finishing operation because it seems to be prematurely disowned.")
                    return
                }
                queue.cancelOperation(operation)
            }
            operation.completionBlock = { _ in
                XCTAssertTrue(Thread.isMainThread)
                completionBlockDidRunExpectation.fulfill()
            }
            return operation
        }()
        
        // The queue should take ownership of the operation (asserted below).
        queue.add(operation!)
        
        // Verify something other than this scope has ownership of the operation.
        weak var addedOperation = operation!
        operation = nil
        XCTAssertNil(operation)
        XCTAssertNotNil(addedOperation, "Perhaps the queue did not take ownership of the operation?")

		let didDisownOperationExpectation = expectation(description: "Did Disown Operation")
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak addedOperation] in
			XCTAssertNil(addedOperation, "Perhaps the queue did not disown the operation?")
			didDisownOperationExpectation.fulfill()
		}

        // Wait for the operation to start running, cancel and complete.
        waitForExpectations(timeout: 1)
     }

	func testCancellingOperationsWithName() {
		let queue = MainThreadOperationQueue()
		queue.suspend()

		let operationsCount = 100
		for i in 0..<operationsCount {
			let operation = MainThreadBlockOperation {
			}
			operation.name = "\(i)"
			queue.add(operation)

			let operation2 = MainThreadBlockOperation {
			}
			operation2.name = "foo"
			queue.add(operation2)
		}

		queue.resume()
		queue.cancelOperations(named: "33")
		queue.cancelOperations(named: "99")
		queue.cancelOperations(named: "654")
		queue.cancelOperations(named: "foo")
		XCTAssert(queue.pendingOperationsCount == 98)

		queue.cancelAllOperations()
		XCTAssert(queue.pendingOperationsCount == 0)
	}
}
