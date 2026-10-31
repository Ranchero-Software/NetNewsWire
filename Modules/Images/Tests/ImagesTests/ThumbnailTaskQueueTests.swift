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
		#expect(await queue.waitForTurn(key: "running", priority: .visible))

		let oldest = Task { await queue.waitForTurn(key: "oldest", priority: .visible) }
		await Task.yield()
		let middle = Task { await queue.waitForTurn(key: "middle", priority: .visible) }
		await Task.yield()
		let newest = Task { await queue.waitForTurn(key: "newest", priority: .visible) }
		await Task.yield()

		#expect(await oldest.value == false)

		queue.taskDidFinish()
		#expect(await newest.value)
		queue.taskDidFinish()
		#expect(await middle.value)
	}

	@Test func prefetchWaitsBehindVisibleUntilItBecomesVisible() async {
		let queue = ThumbnailTaskQueue(maximumRunningCount: 1, maximumWaitingCount: 10)
		#expect(await queue.waitForTurn(key: "running", priority: .visible))

		let firstPrefetch = Task { await queue.waitForTurn(key: "firstPrefetch", priority: .prefetch) }
		await Task.yield()
		let visible = Task { await queue.waitForTurn(key: "visible", priority: .visible) }
		await Task.yield()
		let secondPrefetch = Task { await queue.waitForTurn(key: "secondPrefetch", priority: .prefetch) }
		await Task.yield()

		// Visible goes first, even though the second prefetch was requested later.
		queue.taskDidFinish()
		#expect(await visible.value)

		// The first prefetch became visible, so it goes ahead of the newer second prefetch.
		queue.prioritize(key: "firstPrefetch")
		queue.taskDidFinish()
		#expect(await firstPrefetch.value)
		queue.taskDidFinish()
		#expect(await secondPrefetch.value)
	}

	@Test func articleViewImageStartsWithoutWaitingForASlot() async {
		let queue = ThumbnailTaskQueue(maximumRunningCount: 1, maximumWaitingCount: 10)
		#expect(await queue.waitForTurn(key: "running", priority: .visible))

		let articleImage = Task { await queue.waitForTurn(key: "articleImage", priority: .prefetch) }
		await Task.yield()

		// Starts while the running download still holds the only slot.
		queue.startNow(key: "articleImage")
		#expect(await articleImage.value)
	}
}
