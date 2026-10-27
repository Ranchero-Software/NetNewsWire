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
/// When too many are waiting, the oldest are dropped, since their rows are likely long gone.
/// A dropped row that comes back asks again, and goes to the front.
@MainActor final class DownloadLimiter {

	private let maximumConcurrentDownloads: Int
	private let maximumWaitingDownloads: Int
	private var runningCount = 0
	private var waiting = [CheckedContinuation<Bool, Never>]()

	init(maximumConcurrentDownloads: Int, maximumWaitingDownloads: Int) {
		self.maximumConcurrentDownloads = maximumConcurrentDownloads
		self.maximumWaitingDownloads = maximumWaitingDownloads
	}

	/// False when offline or in Low Data Mode.
	var networkAllowsDownloads: Bool {
		NetworkMonitor.shared.isConnected && !NetworkMonitor.shared.isConstrained
	}

	/// Returns true when the download may start. Call `downloadDidFinish` after it finishes.
	/// Returns false when the download was dropped. Don’t call `downloadDidFinish` then.
	func waitForTurn() async -> Bool {
		if runningCount < maximumConcurrentDownloads {
			runningCount += 1
			return true
		}
		return await withCheckedContinuation { continuation in
			waiting.append(continuation)
			if waiting.count > maximumWaitingDownloads {
				waiting.removeFirst().resume(returning: false)
			}
		}
	}

	func downloadDidFinish() {
		// The finished download’s slot passes straight to the next one.
		if let next = waiting.popLast() {
			next.resume(returning: true)
		} else {
			runningCount -= 1
		}
	}
}
