//
//  MainThreadOperationQueue.swift
//  RSCore
//
//  Created by Brent Simmons on 1/10/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol MainThreadOperationDelegate: AnyObject {
	func operationDidComplete(_ operation: MainThreadOperation)
	func cancelOperation(_ operation: MainThreadOperation)
	func make(_ childOperation: MainThreadOperation, dependOn parentOperation: MainThreadOperation)
}

/// Manage a queue of MainThreadOperation tasks.
///
/// Runs them one at a time; runs them on the main thread.
/// Any operation can use DispatchQueue or whatever to run code off of the main thread.
/// An operation calls back to the queue when it’s completed or canceled.
///
/// Use this only on the main thread.
/// The operation can be suspended and resumed.
/// It is *not* suspended on creation.
public final class MainThreadOperationQueue {

	/// Use the shared queue when you don’t need to create a separate queue.
	public static let shared: MainThreadOperationQueue = {
		MainThreadOperationQueue()
	}()

	private var operations = [Int: MainThreadOperation]()
	private var pendingOperationIDs = [Int]()
	private var currentOperationID: Int?
	private static var incrementingID = 0
	private var isSuspended = false
	private let dependencies = MainThreadOperationDependencies()

	/// Meant for testing; not intended to be useful.
	public var pendingOperationsCount: Int {
		return pendingOperationIDs.count
	}

	public init() {
		// Silence compiler complaint about init not being public.
	}

	deinit {
		cancelAllOperations()
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

	/// Add multiple operations to the queue.
	/// This has the same effect as calling addOperation one-by-one.
	public func addOperations(_ operations: [MainThreadOperation]) {
		for operation in operations {
			add(operation)
		}
	}

	/// Add a dependency. Do this *before* calling addOperation, since addOperation might run the operation right away.
	public func make(_ childOperation: MainThreadOperation, dependOn parentOperation: MainThreadOperation) {
		precondition(Thread.isMainThread)
		let childOperationID = ensureOperationID(childOperation)
		let parentOperationID = ensureOperationID(parentOperation)
		dependencies.make(childOperationID, dependOn: parentOperationID)
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

	/// Cancel some operations. If any of them have dependent operations,
	/// those operations will be canceled also.
	public func cancelOperations(_ operations: [MainThreadOperation]) {
		precondition(Thread.isMainThread)
		let operationIDsToCancel = operations.map{ ensureOperationID($0) }
		assert(allOperationIDsArePendingOrCurrent(operationIDsToCancel))
		assert(allOperationIDsAreInStorage(operationIDsToCancel))

		cancel(operationIDsToCancel)
		runNextOperationIfNeeded()
	}

	/// Cancel operations with the given name. If any of them have dependent
	/// operations, they will be canceled too.
	///
	/// This will cancel the current operation, not just pending operations,
	/// if it has the specified name.
	public func cancelOperations(named name: String) {
		precondition(Thread.isMainThread)
		guard let operationsToCancel = pendingAndCurrentOperations(named: name) else {
			return
		}
		cancelOperations(operationsToCancel)
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

		if operation.isCanceled {
			dependencies.operationIDWasCanceled(operationID)
		}
		else {
			dependencies.operationIDDidComplete(operationID)
		}

		callCompletionBlock(for: operation)
		removeFromStorage(operation)
		operation.operationDelegate = nil
		runNextOperationIfNeeded()
	}

	func runNextOperationIfNeeded() {
		DispatchQueue.main.async {
			guard !self.isSuspended && !self.isRunningAnOperation() else {
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
				dependencies.operationIDWillRun(operationID)
				return operation
			}
		}
		return nil
	}

	func operationIsAvailable(_ operation: MainThreadOperation) -> Bool {
		return !operation.isCanceled && !dependencies.operationIDIsBlockedByDependency(operation.id!)
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
		
		let operationIDsToCancel = operationIDsByAddingChildOperationIDs(operationIDs)
		setCanceledAndRemoveDelegate(for: operationIDsToCancel)
		callCompletionBlockForOperationIDs(operationIDsToCancel)
		clearCurrentOperationIDIfContained(by: operationIDsToCancel)
		removeOperationIDsFromPendingOperationIDs(operationIDsToCancel)
		removeOperationIDsFromStorage(operationIDsToCancel)
		dependencies.cancel(operationIDsToCancel)
	}

	func operationIDsByAddingChildOperationIDs(_ operationIDs: [Int]) -> [Int] {
		var operationIDsToCancel = operationIDs
		for operationID in operationIDs {
			if let childOperationIDs = dependencies.childOperationIDs(for: operationID) {
				operationIDsToCancel += childOperationIDs
			}
		}
		return operationIDsToCancel
	}

	func setCanceledAndRemoveDelegate(for operationIDs: [Int]) {
		for operationID in operationIDs {
			if let operation = operations[operationID] {
				operation.isCanceled = true
				operation.operationDelegate = nil
			}
		}
	}

	func clearCurrentOperationIDIfContained(by operationIDs: [Int]) {
		if let currentOperationID = currentOperationID, operationIDs.contains(currentOperationID) {
			self.currentOperationID = nil
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

private final class MainThreadOperationDependencies {

	private var dependencies = [Int: Dependency]() // Key is parentOperationID

	private final class Dependency {

		let operationID: Int
		var parentOperationDidComplete = false
		var isEmpty: Bool {
			return childOperationIDs.isEmpty
		}
		var childOperationIDs = [Int]()

		init(operationID: Int) {
			self.operationID = operationID
		}

		func remove(_ childOperationID: Int) {
			if let ix = childOperationIDs.firstIndex(of: childOperationID) {
				childOperationIDs.remove(at: ix)
			}
		}

		func add(_ childOperationID: Int) {
			guard !childOperationIDs.contains(childOperationID) else {
				return
			}
			childOperationIDs.append(childOperationID)
		}

		func operationIDIsBlocked(_ operationID: Int) -> Bool {
			if parentOperationDidComplete {
				return false
			}
			return childOperationIDs.contains(operationID)
		}
	}

	/// Add a dependency: make childOperationID dependent on parentOperationID.
	func make(_ childOperationID: Int, dependOn parentOperationID: Int) {
		let dependency = ensureDependency(parentOperationID)
		dependency.add(childOperationID)
	}

	/// Child operationIDs for a possible dependency.
	func childOperationIDs(for parentOperationID: Int) -> [Int]? {
		if let dependency = dependencies[parentOperationID] {
			return dependency.childOperationIDs
		}
		return nil
	}

	/// Update dependencies when an operation is completed.
	func operationIDDidComplete(_ operationID: Int) {
		if let dependency = dependencies[operationID] {
			dependency.parentOperationDidComplete = true
		}
		removeChildOperationID(operationID)
		removeEmptyDependencies()
	}

	/// Update dependencies when an operation finished but was canceled.
	func operationIDWasCanceled(_ operationID: Int) {
		removeAllReferencesToOperationIDs([operationID])
	}

	/// Update dependencies when canceling operations.
	func cancel(_ operationIDs: [Int]) {
		removeAllReferencesToOperationIDs(operationIDs)
	}

	/// Update dependencies when an operation is about to run.
	func operationIDWillRun(_ operationID: Int) {
		removeChildOperationIDs([operationID])
	}

	/// Find out if an operationID is blocked by a dependency.
	func operationIDIsBlockedByDependency(_ operationID: Int) -> Bool {
		for dependency in dependencies.values {
			if dependency.operationIDIsBlocked(operationID) {
				return true
			}
		}
		return false
	}

	private func ensureDependency(_ parentOperationID: Int) -> Dependency {
		if let dependency = dependencies[parentOperationID] {
			return dependency
		}
		let dependency = Dependency(operationID: parentOperationID)
		dependencies[parentOperationID] = dependency
		return dependency
	}
}

private extension MainThreadOperationDependencies {

	func removeAllReferencesToOperationIDs(_ operationIDs: [Int]) {
		removeDependencies(operationIDs)
		removeChildOperationIDs(operationIDs)
	}

	func removeDependencies(_ parentOperationIDs: [Int]) {
		for parentOperationID in parentOperationIDs {
			dependencies[parentOperationID] = nil
		}
	}

	func removeChildOperationIDs(_ operationIDs: [Int]) {
		for operationID in operationIDs {
			removeChildOperationID(operationID)
		}
		removeEmptyDependencies()
	}

	func removeChildOperationID(_ operationID: Int) {
		for value in dependencies.values {
			value.remove(operationID)
		}
	}

	func removeEmptyDependencies() {
		let parentOperationIDs = dependencies.keys
		for parentOperationID in parentOperationIDs {
			let dependency = dependencies[parentOperationID]!
			if dependency.isEmpty {
				dependencies[parentOperationID] = nil
			}
		}
	}
}
