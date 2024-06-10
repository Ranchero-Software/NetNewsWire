//
//  PostponingBlock.swift
//
//
//  Created by Brent Simmons on 6/9/24.
//

import Foundation

/// Runs a block of code in the future. Each time `runInFuture` is called, the block is postponed again until the future by `delayInterval`.
@MainActor public final class PostponingBlock {

	private let block: () -> Void
	private let delayInterval: TimeInterval
	private let name: String // For debugging
	private var timer: Timer?

	public init(delayInterval: TimeInterval, name: String, block: @escaping () -> Void) {

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
		}
		timer = nil
	}
}
