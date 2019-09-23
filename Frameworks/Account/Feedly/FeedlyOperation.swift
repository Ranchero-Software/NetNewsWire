//
//  FeedlyOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlyOperationDelegate: class {
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error)
}

/// Abstract class common to all the tasks required to ingest content from Feedly into NetNewsWire.
/// Each task should try to have a single responsibility so they can be easily composed with others.
class FeedlyOperation: Operation {
	
	weak var delegate: FeedlyOperationDelegate?
	
	func didFinish() {
		self.isExecutingOperation = false
		self.isFinishedOperation = true
	}
	
	func didFinish(_ error: Error) {
		assert(delegate != nil)
		delegate?.feedlyOperation(self, didFailWith: error)
		didFinish()
	}
	
	override func start() {
		isExecutingOperation = true
		DispatchQueue.main.async {
			self.main()
		}
	}
	
	override func cancel() {
		super.cancel()
	}
	
	override var isExecuting: Bool {
		return isExecutingOperation
	}
	
	var isExecutingOperation = false {
		willSet {
			willChangeValue(for: \.isExecuting)
		}
		didSet {
			didChangeValue(for: \.isExecuting)
		}
	}
	
	override var isFinished: Bool {
		return isFinishedOperation
	}
	
	private var isFinishedOperation = false {
		willSet {
			willChangeValue(for: \.isFinished)
		}
		didSet {
			didChangeValue(for: \.isFinished)
		}
	}
}
