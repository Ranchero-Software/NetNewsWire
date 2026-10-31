//
//  ThumbnailTaskQueue.swift
//  Images
//
//  Created by Brent Simmons on 10/25/26.
//

import Foundation

public enum ThumbnailPriority: Sendable {
	case visible // Shown now
	case prefetch // Expected to be shown soon
}

/// Decides when thumbnail tasks, such as downloads, may start, and limits how many run at once.
///
/// Tasks start most-recent-first, so images for rows the user just scrolled to go ahead
/// of rows already scrolled past. Prefetch tasks start only when no visible task
/// is waiting. A waiting task whose row becomes visible moves to the front.
///
/// When too many are waiting, prefetches are dropped first, then the oldest visible tasks,
/// since their rows are likely long gone. A dropped row that comes back asks again.
@MainActor final class ThumbnailTaskQueue {

	private struct WaitingTask {
		let key: String
		let priority: ThumbnailPriority
		let continuation: CheckedContinuation<Bool, Never>
	}

	private let maximumRunningCount: Int
	private let maximumWaitingCount: Int
	private var runningCount = 0
	private var waiting = [WaitingTask]() // Prefetches, then visible. Next to start is last.

	var waitingCount: Int {
		waiting.count
	}

	init(maximumRunningCount: Int, maximumWaitingCount: Int) {
		self.maximumRunningCount = maximumRunningCount
		self.maximumWaitingCount = maximumWaitingCount
	}

	/// Returns true when the task may start. Call `taskDidFinish` after it finishes.
	/// Returns false when the task was dropped. Don’t call `taskDidFinish` then.
	func waitForTurn(key: String, priority: ThumbnailPriority) async -> Bool {
		if runningCount < maximumRunningCount {
			runningCount += 1
			return true
		}
		return await withCheckedContinuation { continuation in
			let waitingTask = WaitingTask(key: key, priority: priority, continuation: continuation)
			switch priority {
			case .visible:
				waiting.append(waitingTask)
			case .prefetch:
				let firstVisibleIndex = waiting.firstIndex { $0.priority == .visible } ?? waiting.endIndex
				waiting.insert(waitingTask, at: firstVisibleIndex)
			}
			if waiting.count > maximumWaitingCount {
				waiting.removeFirst().continuation.resume(returning: false)
			}
		}
	}

	func taskDidFinish() {
		// The finished task’s slot passes straight to the next one.
		if let next = waiting.popLast() {
			next.continuation.resume(returning: true)
		} else {
			runningCount -= 1
		}
	}

	/// Moves a waiting task to the front.
	func prioritize(key: String) {
		guard let index = waiting.lastIndex(where: { $0.key == key }) else {
			return
		}
		let waitingTask = waiting.remove(at: index)
		waiting.append(WaitingTask(key: key, priority: .visible, continuation: waitingTask.continuation))
	}

	/// Starts a waiting task now, even when that goes over the limit.
	func startNow(key: String) {
		guard let index = waiting.lastIndex(where: { $0.key == key }) else {
			return
		}
		let waitingTask = waiting.remove(at: index)
		runningCount += 1
		waitingTask.continuation.resume(returning: true)
	}
}
