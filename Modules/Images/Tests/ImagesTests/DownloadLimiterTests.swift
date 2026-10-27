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
		#expect(await limiter.waitForTurn())

		let oldest = Task { await limiter.waitForTurn() }
		await Task.yield()
		let middle = Task { await limiter.waitForTurn() }
		await Task.yield()
		let newest = Task { await limiter.waitForTurn() }
		await Task.yield()

		#expect(await oldest.value == false)

		limiter.downloadDidFinish()
		#expect(await newest.value)
		limiter.downloadDidFinish()
		#expect(await middle.value)
	}
}
