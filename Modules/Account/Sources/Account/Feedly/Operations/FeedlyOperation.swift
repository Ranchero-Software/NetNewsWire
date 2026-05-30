//
//  FeedlyOperation.swift
//  Account
//
//  Created by Kiel Gillard on 20/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import ActivityLog
import RSWeb
import RSCore

protocol FeedlyOperationDelegate: AnyObject {
	func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error)
}

/// Abstract base class for Feedly sync operations.
///
/// Normally we don’t do inheritance — but in this case
/// it’s the best option.
@MainActor open class FeedlyOperation: FeedlyMainThreadOperation {

	weak var delegate: FeedlyOperationDelegate?
	var downloadProgress: DownloadProgress? {
		didSet {
			oldValue?.completeTask()
			downloadProgress?.addToNumberOfTasksAndRemaining(1)
		}
	}

	/// Set these before adding the op to its queue to have it report an
	/// Activity Log entry — started on `run()`, completed in `didFinish()`,
	/// failed in `didFinish(with:)`.
	var activityKind: ActivityKind?
	var activityDetail: String?
	var activityAccountID: String?
	private var activityID: Int?

	// FeedlyMainThreadOperation
	public var isCanceled = false {
		didSet {
			if isCanceled {
				didCancel()
			}
		}
	}
	public var id: Int?
	public weak var operationDelegate: FeedlyMainThreadOperationDelegate?
	public var name: String?
	public var completionBlock: FeedlyMainThreadOperation.FeedlyMainThreadOperationCompletionBlock?

	public func run() {
	}

	/// Starts the configured activity (if any). Subclasses call this at the
	/// top of their `run()` override.
	func startActivityIfNeeded() {
		guard activityID == nil, let kind = activityKind, let accountID = activityAccountID else {
			return
		}
		let log = ActivityLog.shared
		let id = log.createActivity(owner: .account(accountID), kind: kind, detail: activityDetail)
		log.didStart(id: id)
		activityID = id
	}

	func didFinish() {
		completeActivityIfNeeded()
		if !isCanceled {
			operationDelegate?.operationDidComplete(self)
		}
		downloadProgress?.completeTask()
	}

	func didFinish(with error: Error) {
		failActivityIfNeeded(error: error)
		delegate?.feedlyOperation(self, didFailWith: error)
		if !isCanceled {
			operationDelegate?.operationDidComplete(self)
		}
		downloadProgress?.completeTask()
	}

	public func didCancel() {
		// On cancel, mark the activity failed so it doesn't linger as "started".
		if activityID != nil {
			failActivityIfNeeded(error: CocoaError(.userCancelled))
		}
		didFinish()
	}

	private func completeActivityIfNeeded() {
		guard let id = activityID else {
			return
		}
		ActivityLog.shared.didComplete(id: id)
		activityID = nil
	}

	private func failActivityIfNeeded(error: Error) {
		guard let id = activityID else {
			return
		}
		ActivityLog.shared.didFail(id: id, error: error)
		activityID = nil
	}
}
