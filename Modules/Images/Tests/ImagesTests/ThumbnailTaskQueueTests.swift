//
//  ThumbnailTaskQueueTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/27/26.
//

import Foundation
import Testing
@testable import Images

@MainActor @Suite struct ThumbnailTaskQueueTests {

	@Test func oldestWaitingDownloadIsDroppedAndNewestGoesFirst() async {
		let queue = ThumbnailTaskQueue(maximumRunningCount: 1, maximumWaitingCount: 2)
		#expect(await queue.waitForTurn(key: "running", priority: .visible) == .start(priority: .visible))

		let oldest = await startWaitingTask(queue: queue, key: "oldest", priority: .visible)
		let middle = await startWaitingTask(queue: queue, key: "middle", priority: .visible)
		let newest = Task { await queue.waitForTurn(key: "newest", priority: .visible) }

		// Waiting for the drop also means the newest task is in the queue.
		#expect(await oldest.value == .dropped)

		queue.taskDidFinish()
		#expect(await newest.value == .start(priority: .visible))
		queue.taskDidFinish()
		#expect(await middle.value == .start(priority: .visible))
	}

	@Test func prefetchWaitsBehindVisibleUntilItBecomesVisible() async {
		let queue = ThumbnailTaskQueue(maximumRunningCount: 1, maximumWaitingCount: 10)
		#expect(await queue.waitForTurn(key: "running", priority: .visible) == .start(priority: .visible))

		let firstPrefetch = await startWaitingTask(queue: queue, key: "firstPrefetch", priority: .prefetch)
		let visible = await startWaitingTask(queue: queue, key: "visible", priority: .visible)
		let secondPrefetch = await startWaitingTask(queue: queue, key: "secondPrefetch", priority: .prefetch)

		// Visible goes first, even though the second prefetch was requested later.
		queue.taskDidFinish()
		#expect(await visible.value == .start(priority: .visible))

		// The first prefetch became visible, so it goes ahead of the newer second prefetch.
		queue.prioritize(key: "firstPrefetch")
		queue.taskDidFinish()
		#expect(await firstPrefetch.value == .start(priority: .visible))
		queue.taskDidFinish()
		#expect(await secondPrefetch.value == .start(priority: .prefetch))
	}

	@Test func articleViewImageStartsWithoutWaitingForASlot() async {
		let queue = ThumbnailTaskQueue(maximumRunningCount: 1, maximumWaitingCount: 10)
		#expect(await queue.waitForTurn(key: "running", priority: .visible) == .start(priority: .visible))

		let articleImage = await startWaitingTask(queue: queue, key: "articleImage", priority: .prefetch)

		// Starts while the running download still holds the only slot.
		queue.startNow(key: "articleImage")
		#expect(await articleImage.value == .startNow)
	}
}

private extension ThumbnailTaskQueueTests {

	/// Returns once the task is in the queue, so the order tasks are queued in doesn’t depend on scheduling.
	func startWaitingTask(queue: ThumbnailTaskQueue, key: String, priority: ThumbnailPriority) async -> Task<ThumbnailTurn, Never> {
		let waitingCount = queue.waitingCount
		let task = Task { await queue.waitForTurn(key: key, priority: priority) }
		while queue.waitingCount == waitingCount {
			await Task.yield()
		}
		return task
	}
}
