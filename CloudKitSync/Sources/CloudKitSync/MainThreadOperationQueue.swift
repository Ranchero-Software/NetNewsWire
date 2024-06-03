//
//  MainThreadOperationQueue.swift
//  CloudKitSync
//
//  Created by Brent Simmons on 1/10/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol MainThreadOperationDelegate: AnyObject {
	
	@MainActor func operationDidComplete(_ operation: MainThreadOperation)
	@MainActor func cancelOperation(_ operation: MainThreadOperation)
}

/// Manage a queue of MainThreadOperation tasks.
/// This is deprecated legacy code. Don’t use it.
///
/// Runs them one at a time; runs them on the main thread.
/// Any operation can use DispatchQueue or whatever to run code off of the main thread.
/// An operation calls back to the queue when it’s completed or canceled.
///
/// Use this only on the main thread.
@MainActor public final class MainThreadOperationQueue {

	private var operations = [Int: MainThreadOperation]()
	private var pendingOperationIDs = [Int]()
	private var currentOperationID: Int?
	private static var incrementingID = 0

	public init() {
		// Silence compiler complaint about init not being public.
	}

	/// Add an operation to the queue.
	public func add(_ operation: MainThreadOperation) {
		precondition(Thread.isMainThread)
		operation.operationDelegate = self
		let operationID = ensureOperationID(operation)
		operations[operationID] = operation

		assert(!pendingOperationIDs.contains(operationID))
		if !pendingOperationIDs.contains(operationID) {
			pendingOperationIDs.append(operationID)
		}

		runNextOperationIfNeeded()
	}

	/// Cancel all the current and pending operations.
	public func cancelAllOperations() {
		precondition(Thread.isMainThread)
		var operationIDsToCancel = pendingOperationIDs
		if let currentOperationID = currentOperationID {
			operationIDsToCancel.append(currentOperationID)
		}
		cancel(operationIDsToCancel)
	}

	/// Cancel some operations.
	public func cancelOperations(_ operations: [MainThreadOperation]) {
		precondition(Thread.isMainThread)
		let operationIDsToCancel = operations.map{ ensureOperationID($0) }
		assert(allOperationIDsArePendingOrCurrent(operationIDsToCancel))
		assert(allOperationIDsAreInStorage(operationIDsToCancel))

		cancel(operationIDsToCancel)
		runNextOperationIfNeeded()
	}
}

extension MainThreadOperationQueue: MainThreadOperationDelegate {

	public func operationDidComplete(_ operation: MainThreadOperation) {
		precondition(Thread.isMainThread)
		operationDidFinish(operation)
	}

	public func cancelOperation(_ operation: MainThreadOperation) {
		cancelOperations([operation])
	}
}

private extension MainThreadOperationQueue {

	var pendingOperations: [MainThreadOperation] {
		return pendingOperationIDs.compactMap { (operationID) -> MainThreadOperation? in
			guard let operation = operations[operationID] else {
				assertionFailure("Expected operation, got nil.")
				return nil
			}
			return operation
		}
	}

	var currentOperation: MainThreadOperation? {
		guard let operationID = currentOperationID else {
			return nil
		}
		return operations[operationID]
	}

	func pendingAndCurrentOperations(named name: String) -> [MainThreadOperation]? {
		var operations = pendingOperations.filter { $0.name == name }
		if let current = currentOperation, current.name == name {
			operations.append(current)
		}
		return operations.isEmpty ? nil : operations
	}

	func operationDidFinish(_ operation: MainThreadOperation) {
		guard let operationID = operation.id else {
			assertionFailure("Expected operation.id, got nil")
			return
		}
		if let currentOperationID = currentOperationID, currentOperationID == operationID {
			self.currentOperationID = nil
		}

		callCompletionBlock(for: operation)
		removeFromStorage(operation)
		operation.operationDelegate = nil
		runNextOperationIfNeeded()
	}

	func runNextOperationIfNeeded() {
		DispatchQueue.main.async {
			guard !self.isRunningAnOperation() else {
				return
			}
			guard let operation = self.popNextAvailableOperation() else {
				return
			}
			self.currentOperationID = operation.id!
			operation.run()
		}
	}

	func isRunningAnOperation() -> Bool {
		return currentOperationID != nil
	}

	func popNextAvailableOperation() -> MainThreadOperation? {
		for operationID in pendingOperationIDs {
			guard let operation = operations[operationID] else {
				assertionFailure("Expected pending operation to be found in operations dictionary.")
				continue
			}
			if operationIsAvailable(operation) {
				removeOperationIDsFromPendingOperationIDs([operationID])
				return operation
			}
		}
		return nil
	}

	func operationIsAvailable(_ operation: MainThreadOperation) -> Bool {
		return !operation.isCanceled
	}

	func createOperationID() -> Int {
		precondition(Thread.isMainThread)
		Self.incrementingID += 1
		return Self.incrementingID
	}

	func ensureOperationID(_ operation: MainThreadOperation) -> Int {
		if let operationID = operation.id {
			return operationID
		}

		let operationID = createOperationID()
		operation.id = operationID
		return operationID
	}

	func cancel(_ operationIDs: [Int]) {
		guard !operationIDs.isEmpty else {
			return
		}
		
		setCanceledAndRemoveDelegate(for: operationIDs)
		callCompletionBlockForOperationIDs(operationIDs)
		removeOperationIDsFromPendingOperationIDs(operationIDs)
		removeOperationIDsFromStorage(operationIDs)
	}

	func setCanceledAndRemoveDelegate(for operationIDs: [Int]) {
		for operationID in operationIDs {
			if let operation = operations[operationID] {
				operation.isCanceled = true
				operation.operationDelegate = nil
			}
		}
	}

	func removeOperationIDsFromPendingOperationIDs(_ operationIDs: [Int]) {
		var updatedPendingOperationIDs = pendingOperationIDs
		for operationID in operationIDs {
			if let ix = updatedPendingOperationIDs.firstIndex(of: operationID) {
				updatedPendingOperationIDs.remove(at: ix)
			}
		}

		pendingOperationIDs = updatedPendingOperationIDs
	}

	func removeFromStorage(_ operation: MainThreadOperation) {
		guard let operationID = operation.id else {
			assertionFailure("Expected operation.id, got nil.")
			return
		}
		removeOperationIDsFromStorage([operationID])
	}

	func removeOperationIDsFromStorage(_ operationIDs: [Int]) {
		DispatchQueue.main.async { [weak self] in
			for operationID in operationIDs {
				self?.operations[operationID] = nil
			}
		}
	}

	func callCompletionBlockForOperationIDs(_ operationIDs: [Int]) {
		let completedOperations = operationIDs.compactMap { operations[$0] }
		callCompletionBlockForOperations(completedOperations)
	}

	func callCompletionBlockForOperations(_ operations: [MainThreadOperation]) {
		for operation in operations {
			callCompletionBlock(for: operation)
		}
	}

	func callCompletionBlock(for operation: MainThreadOperation) {
		guard let completionBlock = operation.completionBlock else {
			return
		}
		completionBlock(operation)
		operation.completionBlock = nil
	}

	func allOperationIDsArePendingOrCurrent(_ operationIDs: [Int]) -> Bool {
		// Used by an assert.
		for operationID in operationIDs {
			if currentOperationID != operationID && !pendingOperationIDs.contains(operationID) {
				return false
			}
		}
		return true
	}

	func allOperationIDsAreInStorage(_ operationIDs: [Int]) -> Bool {
		// Used by an assert.
		for operationID in operationIDs {
			guard let _ = operations[operationID] else {
				return false
			}
		}
		return true
	}
}
