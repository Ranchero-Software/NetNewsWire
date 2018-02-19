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

public final class BatchUpdate {
	
	public static let shared = BatchUpdate()
	
	private var count = 0
	
	public var isPerforming: Bool {
		return count > 0
	}
	
	public func perform(_ batchUpdateBlock: BatchUpdateBlock) {
		
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
				assertionFailure("Expected batch updates count to be 0 or greater.")
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
