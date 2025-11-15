//
//  MainThreadOperation.swift
//  RSCore
//
//  Created by Brent Simmons on 1/10/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization

/// Code to be run by MainThreadOperationQueue on @MainActor.
///
/// Override `run()` with the code to be run — this is the only
/// thing that needs to be overridden.
///
/// When finished, it must call `didComplete()`.
///
/// It should check `isCanceled` at appropriate times,
/// and do its best stop when canceled.
/// However, it should not leave data in an inconsistent state.
///
/// The completion block will be called when finished,
/// regardless of cancellation status. The completion block
/// takes the operation as a parameter so that it can check
/// cancellation status if it needs to.
nonisolated open class MainThreadOperation: Hashable, @unchecked Sendable {
	public let id: Int
	private static let nextID = Mutex(0)

	private struct State: Sendable {
		var isCanceled = false
	}
	private let state = Mutex(State())

	// Check this at appropriate times in case the operation has been canceled.
	public var isCanceled: Bool {
		get { state.withLock { $0.isCanceled } }
		set { state.withLock { $0.isCanceled = newValue } }
	}

	public let name: String?

	public typealias MainThreadOperationCompletionBlock = @MainActor @Sendable (MainThreadOperation) -> Void
	public var completionBlock: MainThreadOperationCompletionBlock?

	@MainActor public weak var operationQueue: MainThreadOperationQueue?

	@MainActor var dependencies = Set<MainThreadOperation>()

	/// Create a new MainThreadOperation.
	///
	/// This doesn’t add the operation to the queue.
	/// Call `MainThreadOperationQueue.add` to add it.
	///
	/// - Parameters:
	///   - name: Name of the operation — used for debugging.
	///   - completionBlock: Called on the main thread once the operation has completed.
	///   Called even if canceled, even if `run` was never called.
	public init(name: String? = nil, completionBlock: MainThreadOperationCompletionBlock? = nil) {
		self.id = Self.autoincrementingID()
		self.name = name
		self.completionBlock = completionBlock
	}

	/// Do the thing this operation does. This method must be subclassed.
	///
	/// This code runs on the main thread. You can run code off the main
	/// thread via the standard ways.
	@MainActor open func run() {
		preconditionFailure("MainThreadOperation.run must be overridden.")
	}

	/// Cancel this operation.
	///
	/// Any operations dependent on this operation
	/// will also be canceled automatically.
	@MainActor public func cancel() {
		isCanceled = true
		dependencies.removeAll()
		Task { @MainActor in
			didComplete()
		}
	}

	/// Make this operation dependent on an other operation.
	///
	/// Do this before adding to the queue, since it might get run
	/// before adding the dependency if you add to the queue first.
	///
	/// The other operation must complete before
	/// this operation gets run. If the other operation is canceled,
	/// this operation will automatically be canceled.
	/// Note: an operation can have multiple dependencies.
	@MainActor public func addDependency(_ parentOperation: MainThreadOperation) {
		dependencies.insert(parentOperation)
	}

	@MainActor func removeDependency(_ parentOperation: MainThreadOperation) {
		dependencies.remove(parentOperation)
	}

	@MainActor func hasDependency(_ parentOperation: MainThreadOperation) -> Bool {
		dependencies.contains(parentOperation)
	}

	/// Call when completed. This will trigger calling completionBlock.
	nonisolated public func didComplete() {
		if Thread.isMainThread {
			MainActor.assumeIsolated {
				operationQueue?.operationDidComplete(self)
			}
		} else {
			Task { @MainActor in
				didComplete()
			}
		}
	}

	/// Override to be notified when the operation is complete.
	@MainActor open func noteDidComplete() {
	}

	@MainActor func callCompletionBlock() {
		completionBlock?(self)
		completionBlock = nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	// MARK: - Equatable

	static public func ==(lhs: MainThreadOperation, rhs: MainThreadOperation) -> Bool {
		lhs.id == rhs.id
	}
}

nonisolated private extension MainThreadOperation {

	static func autoincrementingID() -> Int {
		nextID.withLock { id in
			defer {
				id += 1
			}
			return id
		}
	}
}
