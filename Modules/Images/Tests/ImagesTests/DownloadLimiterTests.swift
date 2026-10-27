//
//  DownloadLimiterTests.swift
//  ImagesTests
//
//  Created by Brent Simmons on 10/27/26.
//

import Foundation
import Testing
@testable import Images

@MainActor @Suite struct DownloadLimiterTests {

	@Test func oldestWaitingDownloadIsDroppedAndNewestGoesFirst() async {
		let limiter = DownloadLimiter(maximumConcurrentDownloads: 1, maximumWaitingDownloads: 2)
		#expect(await limiter.waitForTurn(key: "running", priority: .visible))

		let oldest = Task { await limiter.waitForTurn(key: "oldest", priority: .visible) }
		await Task.yield()
		let middle = Task { await limiter.waitForTurn(key: "middle", priority: .visible) }
		await Task.yield()
		let newest = Task { await limiter.waitForTurn(key: "newest", priority: .visible) }
		await Task.yield()

		#expect(await oldest.value == false)

		limiter.downloadDidFinish()
		#expect(await newest.value)
		limiter.downloadDidFinish()
		#expect(await middle.value)
	}

	@Test func prefetchWaitsBehindVisibleUntilItBecomesVisible() async {
		let limiter = DownloadLimiter(maximumConcurrentDownloads: 1, maximumWaitingDownloads: 10)
		#expect(await limiter.waitForTurn(key: "running", priority: .visible))

		let firstPrefetch = Task { await limiter.waitForTurn(key: "firstPrefetch", priority: .prefetch) }
		await Task.yield()
		let visible = Task { await limiter.waitForTurn(key: "visible", priority: .visible) }
		await Task.yield()
		let secondPrefetch = Task { await limiter.waitForTurn(key: "secondPrefetch", priority: .prefetch) }
		await Task.yield()

		// Visible goes first, even though the second prefetch was requested later.
		limiter.downloadDidFinish()
		#expect(await visible.value)

		// The first prefetch became visible, so it goes ahead of the newer second prefetch.
		limiter.prioritize(key: "firstPrefetch")
		limiter.downloadDidFinish()
		#expect(await firstPrefetch.value)
		limiter.downloadDidFinish()
		#expect(await secondPrefetch.value)
	}
}
