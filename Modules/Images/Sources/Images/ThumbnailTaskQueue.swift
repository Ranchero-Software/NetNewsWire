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

enum ThumbnailTurn: Equatable, Sendable {
	case dropped
	case start(priority: ThumbnailPriority) // The priority now, which a wait can raise from prefetch to visible
	case startNow // Started by `startNow`, whatever its priority
}

/// Decides when thumbnail tasks, such as downloads, may start, and limits how many run at once.
///
/// Tasks start most-recent-first, so images for rows the user just scrolled to go ahead
/// of rows already scrolled past. Prefetch tasks start only when no visible task
/// that has room in its group is waiting. A waiting task whose row becomes visible moves to the front.
///
/// Tasks can have a group, such as a download’s host, so that a slow group can’t take every slot.
///
/// When too many are waiting, prefetches are dropped first, then the oldest visible tasks,
/// since their rows are likely long gone. A dropped row that comes back asks again.
@MainActor final class ThumbnailTaskQueue {

	private struct WaitingTask {
		let key: String
		let group: String?
		let priority: ThumbnailPriority
		let continuation: CheckedContinuation<ThumbnailTurn, Never>
	}

	private let maximumRunningCount: Int
	private let maximumWaitingCount: Int
	private let maximumRunningCountPerGroup: Int
	private var runningCount = 0
	private var runningCountPerGroup = [String: Int]()
	private var waiting = [WaitingTask]() // Prefetches, then visible. Next to start is last.

	var waitingCount: Int {
		waiting.count
	}

	init(maximumRunningCount: Int, maximumWaitingCount: Int, maximumRunningCountPerGroup: Int = .max) {
		self.maximumRunningCount = maximumRunningCount
		self.maximumWaitingCount = maximumWaitingCount
		self.maximumRunningCountPerGroup = maximumRunningCountPerGroup
	}

	/// Call `taskDidFinish` with the same group after the task finishes, unless it was dropped.
	func waitForTurn(key: String, group: String? = nil, priority: ThumbnailPriority) async -> ThumbnailTurn {
		if runningCount < maximumRunningCount, hasRoom(in: group) {
			noteTaskStarted(group: group)
			return .start(priority: priority)
		}
		return await withCheckedContinuation { continuation in
			let waitingTask = WaitingTask(key: key, group: group, priority: priority, continuation: continuation)
			switch priority {
			case .visible:
				waiting.append(waitingTask)
			case .prefetch:
				let firstVisibleIndex = waiting.firstIndex { $0.priority == .visible } ?? waiting.endIndex
				waiting.insert(waitingTask, at: firstVisibleIndex)
			}
			if waiting.count > maximumWaitingCount {
				waiting.removeFirst().continuation.resume(returning: .dropped)
			}
		}
	}

	func taskDidFinish(group: String? = nil) {
		runningCount -= 1
		if let group {
			runningCountPerGroup[group, default: 0] -= 1
			if runningCountPerGroup[group] == 0 {
				runningCountPerGroup[group] = nil
			}
		}

		guard runningCount < maximumRunningCount, let index = waiting.lastIndex(where: { hasRoom(in: $0.group) }) else {
			return
		}
		let next = waiting.remove(at: index)
		noteTaskStarted(group: next.group)
		next.continuation.resume(returning: .start(priority: next.priority))
	}

	/// Moves a waiting task to the front.
	func prioritize(key: String) {
		guard let index = waiting.lastIndex(where: { $0.key == key }) else {
			return
		}
		let waitingTask = waiting.remove(at: index)
		waiting.append(WaitingTask(key: key, group: waitingTask.group, priority: .visible, continuation: waitingTask.continuation))
	}

	/// Starts a waiting task now, even when that goes over the limit.
	func startNow(key: String) {
		guard let index = waiting.lastIndex(where: { $0.key == key }) else {
			return
		}
		let waitingTask = waiting.remove(at: index)
		noteTaskStarted(group: waitingTask.group)
		waitingTask.continuation.resume(returning: .startNow)
	}
}

private extension ThumbnailTaskQueue {

	func hasRoom(in group: String?) -> Bool {
		guard let group else {
			return true
		}
		return runningCountPerGroup[group, default: 0] < maximumRunningCountPerGroup
	}

	func noteTaskStarted(group: String?) {
		runningCount += 1
		if let group {
			runningCountPerGroup[group, default: 0] += 1
		}
	}
}
