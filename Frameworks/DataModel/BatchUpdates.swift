//
//  BatchUpdates.swift
//  DataModel
//
//  Created by Brent Simmons on 9/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

private final class BatchUpdatesTracker {
	
	private var batchUpdatesCount = 0
	
	var isPerformingBatchUpdates: Bool {
		get {
			return batchUpdatesCount > 0
		}
	}
	
	func incrementBatchUpdatesCount() {
		
		batchUpdatesCount = batchUpdatesCount + 1
	}
	
	func decrementBatchUpdatesCount() {
		
		batchUpdatesCount = batchUpdatesCount - 1
		
		if batchUpdatesCount < 1 {
			
			if batchUpdatesCount < 0 {
				assertionFailure("Batch updates count should never be below 0.")
				batchUpdatesCount = 0
			}
			
			batchUpdatesCount = 0
			postDataModelDidPerformBatchUpdates()
		}
	}
	
	func postDataModelDidPerformBatchUpdates() {
		
		NotificationCenter.default.post(name: .DataModelDidPerformBatchUpdates, object: nil)
	}
	
}

fileprivate let batchUpdatesTracker = BatchUpdatesTracker()

public func dataModelIsPerformingBatchUpdates() -> Bool {
	
	return batchUpdatesTracker.isPerformingBatchUpdates
}

public typealias BatchUpdatesBlock = () -> Void

public func performDataModelBatchUpdates(_ batchUpdatesBlock: BatchUpdatesBlock) {
	
	startDataModelBatchUpdates()
	
	batchUpdatesBlock()
	
	endDataModelBatchUpdates()
}

private func startDataModelBatchUpdates() {
	
	batchUpdatesTracker.incrementBatchUpdatesCount()
}

private func endDataModelBatchUpdates() {
	
	batchUpdatesTracker.decrementBatchUpdatesCount()
}

