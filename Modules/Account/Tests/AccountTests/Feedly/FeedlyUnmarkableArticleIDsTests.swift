//
//  FeedlyUnmarkableArticleIDsTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 8/3/26.
//

import Foundation
import Testing
@testable import Account

struct FeedlyUnmarkableArticleIDsTests {

	private let cutoffDate = Date(timeIntervalSince1970: 1_000_000)

	@Test func recentArticlesAreMarkable() {
		let dates = ["a": cutoffDate.addingTimeInterval(60)]
		let unmarkableIDs = FeedlyAccountDelegate.unmarkableAsReadArticleIDs(["a"], datesByArticleID: dates, cutoffDate: cutoffDate)
		#expect(unmarkableIDs.isEmpty)
	}

	@Test func oldArticlesAreUnmarkable() {
		let dates = ["a": cutoffDate.addingTimeInterval(-60)]
		let unmarkableIDs = FeedlyAccountDelegate.unmarkableAsReadArticleIDs(["a"], datesByArticleID: dates, cutoffDate: cutoffDate)
		#expect(unmarkableIDs == ["a"])
	}

	@Test func missingArticlesAreUnmarkable() {
		let unmarkableIDs = FeedlyAccountDelegate.unmarkableAsReadArticleIDs(["gone"], datesByArticleID: [:], cutoffDate: cutoffDate)
		#expect(unmarkableIDs == ["gone"])
	}

	@Test func mixedArticlesPartitionCorrectly() {
		let dates = ["new": cutoffDate.addingTimeInterval(60), "old": cutoffDate.addingTimeInterval(-60)]
		let unmarkableIDs = FeedlyAccountDelegate.unmarkableAsReadArticleIDs(["new", "old", "gone"], datesByArticleID: dates, cutoffDate: cutoffDate)
		#expect(unmarkableIDs == ["old", "gone"])
	}
}
