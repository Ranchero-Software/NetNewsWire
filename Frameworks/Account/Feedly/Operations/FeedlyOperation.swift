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
		
		updateExecutingAndFinished(false, true)
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
			updateExecutingAndFinished(false, true)

			if downloadProgress != nil {
				DispatchQueue.main.async {
					self.downloadProgress = nil
				}
			}
			
			return
		}

		updateExecutingAndFinished(true, false)
		DispatchQueue.main.async {
			self.main()
		}
	}
	
	override var isExecuting: Bool {
		return isExecutingOperation
	}
	
	override var isFinished: Bool {
		return isFinishedOperation
	}

	private var isExecutingOperation = false
	private var isFinishedOperation = false

	private func updateExecutingAndFinished(_ executing: Bool, _ finished: Bool) {
		let isExecutingDidChange = executing != isExecutingOperation
		let isFinishedDidChange = finished != isFinishedOperation

		if isFinishedDidChange {
			willChangeValue(for: \.isFinished)
		}
		if isExecutingDidChange {
			willChangeValue(for: \.isExecuting)
		}
		isExecutingOperation = executing
		isFinishedOperation = finished

		if isExecutingDidChange {
			didChangeValue(for: \.isExecuting)
		}
		if isFinishedDidChange {
			didChangeValue(for: \.isFinished)
		}
	}
}
