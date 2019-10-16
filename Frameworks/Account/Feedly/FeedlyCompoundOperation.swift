//
//  FeedlyCompoundOperation.swift
//  Account
//
//  Created by Kiel Gillard on 10/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// An operation with a queue of its own.
final class FeedlyCompoundOperation: FeedlyOperation {
	private let operationQueue = OperationQueue()
	private var finishOperation: BlockOperation?
	
	init(operations: [Operation]) {
		assert(!operations.isEmpty)
		operationQueue.isSuspended = true
		finishOperation = nil
		super.init()
		
		let finish = BlockOperation {
			self.didFinish()
		}
		
		finishOperation = finish
		
		for operation in operations {
			finish.addDependency(operation)
		}
		
		var initialOperations = operations
		initialOperations.append(finish)
		
		operationQueue.addOperations(initialOperations, waitUntilFinished: false)
	}
	
	convenience init(operationsBlock: () -> ([Operation])) {
		let operations = operationsBlock()
		self.init(operations: operations)
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		operationQueue.isSuspended = false
	}
	
	func addAnotherOperation(_ operation: Operation) {
		guard !isCancelled else { return }
		finishOperation?.addDependency(operation)
		operationQueue.addOperation(operation)
	}
	
	override func cancel() {
		operationQueue.cancelAllOperations()
		super.cancel()
	}
}
