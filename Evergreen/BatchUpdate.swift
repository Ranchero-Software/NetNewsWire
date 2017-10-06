//
//  BatchUpdates.swift
//  DataModel
//
//  Created by Brent Simmons on 9/12/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public typealias BatchUpdateBlock = () -> Void

public extension Notification.Name {
	
	public static let BatchUpdateDidPerform = Notification.Name(rawValue: "BatchUpdateDidPerform")
}

final class BatchUpdate {
	
	static let shared = BatchUpdate()
	
	private var count = 0
	
	var isPerforming: Bool {
		get {
			return count > 0
		}
	}
	
	func perform(_ batchUpdateBlock: BatchUpdateBlock) {
		
		incrementCount()
		batchUpdateBlock()
		decrementCount()
	}
}

private extension BatchUpdate {
	
	func incrementCount() {
		
		count = count + 1
	}
	
	func decrementCount() {
		
		count = count - 1
		
		if count < 1 {
			
			if count < 0 {
				assertionFailure("Batch updates count should never be below 0.")
				count = 0
			}
			
			count = 0
			postBatchUpdateDidPerform()
		}
	}
	
	func postBatchUpdateDidPerform() {
		
		NotificationCenter.default.post(name: .BatchUpdateDidPerform, object: nil, userInfo: nil)
	}
}
