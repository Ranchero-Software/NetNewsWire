//
//  MainThreadOperation.swift
//  RSCore
//
//  Created by Brent Simmons on 1/10/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Code to be run by MainThreadOperationQueue.
/// This is deprecated legacy code. Don’t use it.
///
/// When finished, it must call operationDelegate.operationDidComplete(self).
/// If it’s canceled, it should not call the delegate.
/// When it’s canceled, it should do its best to stop
/// doing whatever it’s doing. However, it should not
/// leave data in an inconsistent state.
public protocol MainThreadOperation: AnyObject {

	// These three properties are set by MainThreadOperationQueue. Don’t set them.
	@MainActor var isCanceled: Bool { get set } // Check this at appropriate times in case the operation has been canceled.
	@MainActor var id: Int? { get set }
	@MainActor var operationDelegate: MainThreadOperationDelegate? { get set } // Make this weak.

	/// Name may be useful for debugging. Unused otherwise.
	@MainActor var name: String? { get set }

	typealias MainThreadOperationCompletionBlock = (MainThreadOperation) -> Void

	/// Called when the operation completes.
	///
	/// The completionBlock is called
	/// even if the operation was canceled. The completionBlock
	/// takes the operation as parameter, so you can inspect it as needed.
	///
	/// Implementations of MainThreadOperation are *not* responsible
	/// for calling the completionBlock — MainThreadOperationQueue
	/// handles that.
	///
	/// The completionBlock is always called on the main thread.
	/// The queue will clear the completionBlock after calling it.
	@MainActor var completionBlock: MainThreadOperationCompletionBlock? { get set }

	/// Do the thing this operation does.
	///
	/// This code runs on the main thread. If you want to run
	/// code off of the main thread, you can use the standard mechanisms:
	/// a DispatchQueue, most likely.
	///
	/// When this is called, you don’t need to check isCanceled:
	/// it’s guaranteed to not be canceled. However, if you run code
	/// in another thread, you should check isCanceled in that code.
	@MainActor func run()

	/// Cancel this operation.
	///
	/// Any operations dependent on this operation
	/// will also be canceled automatically.
	///
	/// This function has a default implementation. It’s super-rare
	/// to need to provide your own.
	@MainActor func cancel()
}

public extension MainThreadOperation {

	@MainActor func cancel() {
		operationDelegate?.cancelOperation(self)
	}

	@MainActor func informOperationDelegateOfCompletion() {
		guard !isCanceled else {
			return
		}
		if Thread.isMainThread {
			operationDelegate?.operationDidComplete(self)
		}
		else {
			DispatchQueue.main.async {
				self.informOperationDelegateOfCompletion()
			}
		}
	}
}
