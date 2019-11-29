//
//  FeedlyOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

protocol FeedlyOperationDelegate: class {
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error)
}

/// Abstract class common to all the tasks required to ingest content from Feedly into NetNewsWire.
/// Each task should try to have a single responsibility so they can be easily composed with others.
class FeedlyOperation: Operation {
	
	weak var delegate: FeedlyOperationDelegate?
	
	var downloadProgress: DownloadProgress? {
		didSet {
			guard downloadProgress == nil || !isExecuting else {
				fatalError("\(\FeedlyOperation.downloadProgress) was set to late. Set before operation starts executing.")
			}
			oldValue?.completeTask()
			downloadProgress?.addToNumberOfTasksAndRemaining(1)
		}
	}
	
	func didFinish() {
		assert(Thread.isMainThread)
		assert(!isFinished, "Finished operation is attempting to finish again.")
		
		downloadProgress = nil
		
		isExecutingOperation = false
		isFinishedOperation = true
	}
	
	func didFinish(_ error: Error) {
		assert(Thread.isMainThread)
		assert(!isFinished, "Finished operation is attempting to finish again.")
		delegate?.feedlyOperation(self, didFailWith: error)
		didFinish()
	}
	
	override func cancel() {
		// If the operation never started, disown the download progress.
		if !isExecuting && !isFinished, downloadProgress != nil {
			DispatchQueue.main.async {
				self.downloadProgress = nil
			}
		}
		super.cancel()
	}
	
	override func start() {
		guard !isCancelled else {
			isExecutingOperation = false
			isFinishedOperation = true
			
			if downloadProgress != nil {
				DispatchQueue.main.async {
					self.downloadProgress = nil
				}
			}
			
			return
		}
		
		isExecutingOperation = true
		DispatchQueue.main.async {
			self.main()
		}
	}
	
	override var isExecuting: Bool {
		return isExecutingOperation
	}
	
	private var isExecutingOperation = false {
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
