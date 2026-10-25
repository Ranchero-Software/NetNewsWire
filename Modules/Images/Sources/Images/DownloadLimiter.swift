//
//  DownloadLimiter.swift
//  Images
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import RSWeb

/// Limits how many downloads run at once. Waiting downloads start most-recent-first,
/// so images for rows the user just scrolled to go ahead of rows already scrolled past.
@MainActor final class DownloadLimiter {

	private let maximumConcurrentDownloads: Int
	private var runningCount = 0
	private var waiting = [CheckedContinuation<Void, Never>]()

	init(maximumConcurrentDownloads: Int) {
		self.maximumConcurrentDownloads = maximumConcurrentDownloads
	}

	/// False when offline or in Low Data Mode.
	var networkAllowsDownloads: Bool {
		NetworkMonitor.shared.isConnected && !NetworkMonitor.shared.isConstrained
	}

	/// Returns when a download may start. Call `downloadDidFinish` after it finishes.
	func waitForTurn() async {
		if runningCount < maximumConcurrentDownloads {
			runningCount += 1
			return
		}
		await withCheckedContinuation { continuation in
			waiting.append(continuation)
		}
	}

	func downloadDidFinish() {
		// The finished download’s slot passes straight to the next one.
		if let next = waiting.popLast() {
			next.resume()
		} else {
			runningCount -= 1
		}
	}
}
