//
//  MainThreadBlockOperation.swift
//  RSCore
//
//  Created by Brent Simmons on 1/16/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/// Run a block of code as an operation.
public final class MainThreadBlockOperation: MainThreadOperation, @unchecked Sendable {
	private let block: VoidBlock

	public init(name: String? = nil, block: @escaping VoidBlock) {
		self.block = block
		super.init(name: name, completionBlock: nil)
	}

	@MainActor override public func run() {
		assert(Thread.isMainThread)
		block()
		didComplete()
	}
}
