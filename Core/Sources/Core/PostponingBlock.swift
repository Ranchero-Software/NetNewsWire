//
//  PostponingBlock.swift
//
//
//  Created by Brent Simmons on 6/9/24.
//

import Foundation
import os

/// Runs a block of code in the future. Each time `runInFuture` is called, the block is postponed again until the future by `delayInterval`.
@MainActor public final class PostponingBlock {

	private let block: @MainActor () -> Void
	private let delayInterval: TimeInterval
	private let name: String // For debugging
	private var timer: Timer?

	private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostponingBlock")

	public init(delayInterval: TimeInterval, name: String, block: @MainActor @escaping () -> Void) {

		self.delayInterval = delayInterval
		self.name = name
		self.block = block
	}

	/// Run the block in `delayInterval` seconds, canceling any run about to happen before then.
	public func runInFuture() {

		invalidateTimer()

		timer = Timer.scheduledTimer(withTimeInterval: delayInterval, repeats: false) { timer in
			MainActor.assumeIsolated {
				self.block()
			}
		}
	}

	/// Cancel any upcoming run.
	public func cancelRun() {

		invalidateTimer()
	}
}

private extension PostponingBlock {

	func invalidateTimer() {

		if let timer, timer.isValid {
			timer.invalidate()
			logger.info("Canceling existing timer in PostponingBlock: \(self.name)")
		}
		timer = nil
	}
}
