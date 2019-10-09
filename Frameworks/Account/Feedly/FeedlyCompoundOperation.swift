//
//  FeedlyCompoundOperation.swift
//  Account
//
//  Created by Kiel Gillard on 10/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

final class FeedlyCompoundOperation: FeedlyOperation {
	private let operationQueue = OperationQueue()
	private let operations: [Operation]
	
	init(operations: [Operation]) {
		assert(!operations.isEmpty)
		self.operations = operations
	}
	
	convenience init(operationsBlock: () -> ([Operation])) {
		let operations = operationsBlock()
		self.init(operations: operations)
	}
	
	override func main() {
		let finishOperation = BlockOperation { [weak self] in
			self?.didFinish()
		}
		
		for operation in operations {
			finishOperation.addDependency(operation)
		}
		
		operationQueue.addOperations(operations, waitUntilFinished: false)
	}
}
