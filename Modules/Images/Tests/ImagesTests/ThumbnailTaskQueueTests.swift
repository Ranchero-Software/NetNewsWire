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
		#expect(await queue.waitForTurn(key: "running") == .start)

		let oldest = await startWaitingTask(queue: queue, key: "oldest")
		let middle = await startWaitingTask(queue: queue, key: "middle")
		let newest = Task { await queue.waitForTurn(key: "newest") }

		// Waiting for the drop also means the newest task is in the queue.
		#expect(await oldest.value == .dropped)

		queue.taskDidFinish()
		#expect(await newest.value == .start)
		queue.taskDidFinish()
		#expect(await middle.value == .start)
	}

	@Test func prioritizedTaskGoesAheadOfNewerTask() async {
		let queue = ThumbnailTaskQueue(maximumRunningCount: 1, maximumWaitingCount: 10)
		#expect(await queue.waitForTurn(key: "running") == .start)

		let older = await startWaitingTask(queue: queue, key: "older")
		let newer = await startWaitingTask(queue: queue, key: "newer")

		queue.prioritize(key: "older")
		queue.taskDidFinish()
		#expect(await older.value == .start)
		queue.taskDidFinish()
		#expect(await newer.value == .start)
	}

	@Test func articleViewImageStartsWithoutWaitingForASlot() async {
		let queue = ThumbnailTaskQueue(maximumRunningCount: 1, maximumWaitingCount: 10)
		#expect(await queue.waitForTurn(key: "running") == .start)

		let articleImage = await startWaitingTask(queue: queue, key: "articleImage")

		// Starts while the running download still holds the only slot.
		queue.startNow(key: "articleImage")
		#expect(await articleImage.value == .startNow)
	}

	@Test func downloadsFromSlowHostLeaveSlotsForOtherHosts() async {
		let slowHost = "slow.example.com"
		let fastHost = "fast.example.com"
		let queue = ThumbnailTaskQueue(maximumRunningCount: 2, maximumWaitingCount: 10, maximumRunningCountPerGroup: 1)
		#expect(await queue.waitForTurn(key: "slow1", group: slowHost) == .start)
		let slow2 = await startWaitingTask(queue: queue, key: "slow2", group: slowHost)

		// Starts even though slow2 is waiting, since slow2’s host is at its limit.
		#expect(await queue.waitForTurn(key: "fast1", group: fastHost) == .start)

		let fast2 = await startWaitingTask(queue: queue, key: "fast2", group: fastHost)
		let slow3 = await startWaitingTask(queue: queue, key: "slow3", group: slowHost)

		// slow3 is the newest, but its host is still at its limit.
		queue.taskDidFinish(group: fastHost)
		#expect(await fast2.value == .start)

		queue.taskDidFinish(group: slowHost)
		#expect(await slow3.value == .start)

		queue.taskDidFinish(group: slowHost)
		#expect(await slow2.value == .start)
	}
}

private extension ThumbnailTaskQueueTests {

	/// Returns once the task is in the queue, so the order tasks are queued in doesn’t depend on scheduling.
	func startWaitingTask(queue: ThumbnailTaskQueue, key: String, group: String? = nil) async -> Task<ThumbnailTurn, Never> {
		let waitingCount = queue.waitingCount
		let task = Task { await queue.waitForTurn(key: key, group: group) }
		while queue.waitingCount == waitingCount {
			await Task.yield()
		}
		return task
	}
}
