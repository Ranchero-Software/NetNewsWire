//
//  MainThreadBlockOperation.swift
//  RSCore
//
//  Created by Brent Simmons on 1/16/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Run a block of code as an operation.
///
/// This also serves as a simple example implementation of MainThreadOperation.
public final class MainThreadBlockOperation: MainThreadOperation {

	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public var operationDelegate: MainThreadOperationDelegate?
	public var name: String?
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private let block: VoidBlock

	public init(block: @escaping VoidBlock) {
		self.block = block
	}

	public func run() {
		block()
		informOperationDelegateOfCompletion()
	}
}
