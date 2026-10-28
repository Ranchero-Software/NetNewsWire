//
//  DownloadLimiter.swift
//  Images
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation
import RSWeb

public enum DownloadPriority: Sendable {
	case visible // Shown now
	case prefetch // Expected to be shown soon
}

/// Limits how many downloads run at once.
///
/// Downloads start most-recent-first, so images for rows the user just scrolled to go ahead
/// of rows already scrolled past. Prefetch downloads start only when no visible download
/// is waiting. A waiting download whose row becomes visible moves to the front.
///
/// When too many are waiting, prefetches are dropped first, then the oldest visible downloads,
/// since their rows are likely long gone. A dropped row that comes back asks again.
@MainActor final class DownloadLimiter {

	private struct WaitingDownload {
		let key: String
		let priority: DownloadPriority
		let continuation: CheckedContinuation<Bool, Never>
	}

	private let maximumConcurrentDownloads: Int
	private let maximumWaitingDownloads: Int
	private var runningCount = 0
	private var waiting = [WaitingDownload]() // Prefetches, then visible. Next to start is last.

	init(maximumConcurrentDownloads: Int, maximumWaitingDownloads: Int) {
		self.maximumConcurrentDownloads = maximumConcurrentDownloads
		self.maximumWaitingDownloads = maximumWaitingDownloads
	}

	/// False when offline or in Low Data Mode.
	static var networkAllowsDownloads: Bool {
		NetworkMonitor.shared.isConnected && !NetworkMonitor.shared.isConstrained
	}

	/// Returns true when the download may start. Call `downloadDidFinish` after it finishes.
	/// Returns false when the download was dropped. Don’t call `downloadDidFinish` then.
	func waitForTurn(key: String, priority: DownloadPriority) async -> Bool {
		if runningCount < maximumConcurrentDownloads {
			runningCount += 1
			return true
		}
		return await withCheckedContinuation { continuation in
			let waitingDownload = WaitingDownload(key: key, priority: priority, continuation: continuation)
			switch priority {
			case .visible:
				waiting.append(waitingDownload)
			case .prefetch:
				let firstVisibleIndex = waiting.firstIndex { $0.priority == .visible } ?? waiting.endIndex
				waiting.insert(waitingDownload, at: firstVisibleIndex)
			}
			if waiting.count > maximumWaitingDownloads {
				waiting.removeFirst().continuation.resume(returning: false)
			}
		}
	}

	func downloadDidFinish() {
		// The finished download’s slot passes straight to the next one.
		if let next = waiting.popLast() {
			next.continuation.resume(returning: true)
		} else {
			runningCount -= 1
		}
	}

	/// Moves a waiting download to the front.
	func prioritize(key: String) {
		guard let index = waiting.lastIndex(where: { $0.key == key }) else {
			return
		}
		let waitingDownload = waiting.remove(at: index)
		waiting.append(WaitingDownload(key: key, priority: .visible, continuation: waitingDownload.continuation))
	}

	/// Starts a waiting download now, even when that goes over the limit.
	func startNow(key: String) {
		guard let index = waiting.lastIndex(where: { $0.key == key }) else {
			return
		}
		let waitingDownload = waiting.remove(at: index)
		runningCount += 1
		waitingDownload.continuation.resume(returning: true)
	}
}
