//
//  MainThreadOperationQueue.swift
//  RSCore
//
//  Created by Brent Simmons on 1/10/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Manage a queue of MainThreadOperation tasks.
///
/// Run them one at a time on the main actor.
/// Any operation can use standard mechanisms to run code off of the main thread.
/// An operation calls back to the queue when it’s completed or canceled.
///
/// The operation queue can be suspended and resumed.
/// It is *not* suspended on creation — it is active.
@MainActor public final class MainThreadOperationQueue: ProgressInfoReporter {
	/// Use the shared queue when you don’t need to create a separate queue.
	public static let shared: MainThreadOperationQueue = MainThreadOperationQueue()

	private var pendingOperations = [MainThreadOperation]()
	private var currentOperation: MainThreadOperation?
	private var completedOrCanceledOperationIDs = Set<Int>()
	private var isSuspended = false
	private var hasPendingRunScheduled = false

	/// Controls whether or not `progressInfo` is reported.
	///
	/// Normally you would use this only for a private queue —
	/// for a sync queue private to a specific account, for instance.
	/// You would set it to true at the beginning of a sync session
	/// and set it false when the sync session completes.
	public var isTrackingProgress = false {
		didSet {
			if isTrackingProgress != oldValue {
				completedOrCanceledOperationIDs = Set<Int>()
			}
		}
	}

	/// Reports progress. Valid only when `trackingProgress` is true.
	public var progressInfo = ProgressInfo() {
		didSet {
			if isTrackingProgress && progressInfo != oldValue {
				postProgressInfoDidChangeNotification()
			}
		}
	}

	public var pendingOperationsCount: Int {
		let pendingNonCanceledOperations = pendingOperations.filter({ !$0.isCanceled })
		return pendingNonCanceledOperations.count
	}

	public init() {}

	/// Add an operation to the queue.
	public func add(_ operation: MainThreadOperation) {
		precondition(Thread.isMainThread)

		operation.operationQueue = self

		if pendingOperations.contains(operation) {
			assertionFailure("Tried to add operation to MainThreadOperationQueue that had already been added.")
			return
		}
		pendingOperations.append(operation)

		runNextOperationIfNeeded()
	}

	/// Add multiple operations to the queue.
	/// It’s a convenience — better than calling `add` one-by-one.
	public func add(_ operations: [MainThreadOperation]) {
		for operation in operations {
			add(operation)
		}
	}

	/// Cancel all the current and pending operations.
	public func cancelAll() {
		precondition(Thread.isMainThread)
		var operationsToCancel = Set(pendingOperations)
		if let currentOperation {
			operationsToCancel.insert(currentOperation)
		}

		cancel(Array(operationsToCancel))
	}

	/// Cancel some operations. If any of them have dependent operations,
	/// those operations will be canceled also.
	///
	/// It’s a convenience — better than calling `operation.cancel()` one-by-one.
	public func cancel(_ operations: [MainThreadOperation]) {
		precondition(Thread.isMainThread)
		for operation in operations {
			operation.cancel()
			if isTrackingProgress {
				completedOrCanceledOperationIDs.insert(operation.id)
			}
		}

		runNextOperationIfNeeded()
	}

	/// Cancel operations with the given name. If any of them have dependent
	/// operations, they will be canceled too.
	///
	/// This will cancel the current operation, not just pending operations,
	/// if it has the specified name.
	public func cancel(named name: String) {
		precondition(Thread.isMainThread)
		guard let operationsToCancel = pendingAndCurrentOperations(named: name) else {
			return
		}
		cancel(operationsToCancel)
	}

	/// Stop running operations until resume() is called.
	/// The current operation, if there is one, will run to completion —
	/// it will not be canceled.
	public func suspend() {
		precondition(Thread.isMainThread)
		isSuspended = true
	}

	/// Resume running operations.
	public func resume() {
		precondition(Thread.isMainThread)
		isSuspended = false
		runNextOperationIfNeeded()
	}

	public func operationDidComplete(_ operation: MainThreadOperation) {
		precondition(Thread.isMainThread)

		operation.callCompletionBlock()
		operation.noteDidComplete()

		if isTrackingProgress {
			completedOrCanceledOperationIDs.insert(operation.id)
		}

		pendingOperations.removeAll { $0 == operation }
		if currentOperation == operation {
			currentOperation = nil
		}

		// Handle dependent operations.
		let operationWasCanceled = operation.isCanceled
		let dependentOperations = pendingOperations.filter { $0.hasDependency(operation) }
		for dependentOperation in dependentOperations {
			dependentOperation.removeDependency(operation)
			if operationWasCanceled {
				dependentOperation.cancel()
			}
		}

		removeCanceledOperations()
		runNextOperationIfNeeded()
	}
}

private extension MainThreadOperationQueue {

	func removeCanceledOperations() {
		let canceledOperations = pendingOperations.filter { $0.isCanceled }
		for canceledOperation in canceledOperations {
			pendingOperations.removeAll { $0 == canceledOperation }
		}
		updateProgressInfo()
	}

	func pendingAndCurrentOperations(named name: String) -> [MainThreadOperation]? {
		var operations = pendingOperations.filter { $0.name == name }
		if let current = currentOperation, current.name == name {
			operations.append(current)
		}
		return operations.isEmpty ? nil : operations
	}

	func runNextOperationIfNeeded() {
		updateProgressInfo()

		guard !isSuspended && !hasPendingRunScheduled else {
			return
		}
		hasPendingRunScheduled = true

		Task {
			hasPendingRunScheduled = false
			guard !isSuspended && currentOperation == nil else {
				return
			}
			guard let operation = popNextAvailableOperation() else {
				return
			}
			currentOperation = operation
			updateProgressInfo()
			operation.run()
		}
	}

	func popNextAvailableOperation() -> MainThreadOperation? {
		guard let index = pendingOperations.firstIndex(where: { operationIsAvailable($0) }) else {
			return nil
		}

		let operation = pendingOperations[index]
		pendingOperations.remove(at: index)
		assert(!pendingOperations.contains(where: { $0 == operation }))

		return operation
	}

	func operationIsAvailable(_ operation: MainThreadOperation) -> Bool {
		!operation.isCanceled && operation.dependencies.isEmpty
	}

	func updateProgressInfo() {
		guard isTrackingProgress else {
			return
		}

		let pendingOperationIDs: Set<Int> = {
			var ids = Set(pendingOperations.map(\.id))
			if let currentOperationID = currentOperation?.id {
				ids.insert(currentOperationID)
			}
			return ids.filter { !completedOrCanceledOperationIDs.contains($0) }
		}()

		let numberCompleted = completedOrCanceledOperationIDs.count
		let numberRemaining = pendingOperationIDs.count
		let numberOfTasks = numberCompleted + numberRemaining

		progressInfo = ProgressInfo(numberOfTasks: numberOfTasks,
									numberCompleted: numberCompleted,
									numberRemaining: numberRemaining)
	}
}
