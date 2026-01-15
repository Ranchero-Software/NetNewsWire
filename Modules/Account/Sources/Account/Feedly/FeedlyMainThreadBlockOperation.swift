//
//  FeedlyMainThreadBlockOperation.swift
//  RSCore
//
//  Created by Brent Simmons on 1/16/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

/// Run a block of code as an operation.
///
/// This also serves as a simple example implementation of FeedlyMainThreadOperation.
final class FeedlyMainThreadBlockOperation: FeedlyMainThreadOperation {

	// FeedlyMainThreadOperation
	var isCanceled = false
	var id: Int?
	var operationDelegate: FeedlyMainThreadOperationDelegate?
	var name: String?
	var completionBlock: FeedlyMainThreadOperation.FeedlyMainThreadOperationCompletionBlock?

	private let block: VoidBlock

	init(block: @escaping VoidBlock) {
		self.block = block
	}

	func run() {
		block()
		informOperationDelegateOfCompletion()
	}
}
