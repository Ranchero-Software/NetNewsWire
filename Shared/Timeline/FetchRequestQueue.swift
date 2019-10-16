//
//  FetchRequestQueue.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation

// Main thread only.

final class FetchRequestQueue {

	private var pendingRequests = [FetchRequestOperation]()
	private var currentRequest: FetchRequestOperation? = nil

	func cancelAllRequests() {
		precondition(Thread.isMainThread)
		pendingRequests.forEach { $0.isCanceled = true }
		currentRequest?.isCanceled = true
		pendingRequests = [FetchRequestOperation]()
	}

	func add(_ fetchRequestOperation: FetchRequestOperation) {
		precondition(Thread.isMainThread)
		pendingRequests.append(fetchRequestOperation)
		runNextRequestIfNeeded()
	}
}

private extension FetchRequestQueue {

	func runNextRequestIfNeeded() {
		precondition(Thread.isMainThread)
		removeCanceledAndFinishedRequests()
		guard currentRequest == nil, let requestToRun = pendingRequests.first else {
			return
		}

		currentRequest = requestToRun
		pendingRequests.removeFirst()
		currentRequest!.run { (fetchRequestOperation) in
			precondition(fetchRequestOperation === self.currentRequest)
			self.currentRequest = nil
			self.runNextRequestIfNeeded()
		}
	}

	func removeCanceledAndFinishedRequests() {
		pendingRequests = pendingRequests.filter{ !$0.isCanceled && !$0.isFinished }
	}
}
