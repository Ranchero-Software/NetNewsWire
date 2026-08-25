//
//  FeedlyActivityMessageTests.swift
//  Account
//
//  Created by Brent Simmons on 8/3/26.
//

import Foundation
import Testing
@testable import Account

@MainActor struct FeedlyActivityMessageTests {

	@Test func sendStatusMessageCounts() {
		#expect(FeedlyAccountDelegate.sendStatusMessage(count: 0) == "No statuses to send")
		#expect(FeedlyAccountDelegate.sendStatusMessage(count: 1) == "1 status sent")
		#expect(FeedlyAccountDelegate.sendStatusMessage(count: 2) == "2 statuses sent")
	}

	@Test func refreshStatusMessageWithNoChanges() {
		let counts = FeedlyAccountDelegate.StatusRefreshCounts()
		#expect(FeedlyAccountDelegate.refreshStatusMessage(counts: counts) == "No changes")
	}

	@Test func refreshStatusMessageJoinsPartsInOrder() {
		let counts = FeedlyAccountDelegate.StatusRefreshCounts(unreadAdded: 3, unreadRemoved: 2, starredAdded: 1, starredRemoved: 4)
		#expect(FeedlyAccountDelegate.refreshStatusMessage(counts: counts) == "3 marked unread, 2 marked read, 1 starred, 4 unstarred")
	}

	@Test func feedListMessageWithNoChanges() {
		let changes = FeedlyAccountDelegate.FeedListChanges()
		#expect(FeedlyAccountDelegate.feedListMessage(changes: changes) == "No changes")
	}

	@Test func feedListMessagePluralizes() {
		let singular = FeedlyAccountDelegate.FeedListChanges(foldersAdded: 1, foldersRemoved: 0, feedsAdded: 1, feedsRemoved: 0, feedsRenamed: 0)
		#expect(FeedlyAccountDelegate.feedListMessage(changes: singular) == "1 folder added, 1 feed added")

		let plural = FeedlyAccountDelegate.FeedListChanges(foldersAdded: 0, foldersRemoved: 2, feedsAdded: 0, feedsRemoved: 3, feedsRenamed: 2)
		#expect(FeedlyAccountDelegate.feedListMessage(changes: plural) == "2 folders removed, 3 feeds removed, 2 feeds renamed")
	}

	@Test func refreshAllMessageWithNoChanges() {
		let summary = FeedlyAccountDelegate.RefreshAllSummary()
		#expect(FeedlyAccountDelegate.refreshAllMessage(summary: summary) == "No changes")
	}

	@Test func refreshAllMessageComposesAllPartsInOrder() {
		var summary = FeedlyAccountDelegate.RefreshAllSummary()
		summary.articlesDownloaded = 1
		summary.newArticlesFromFeedRefresh = 2
		summary.statusRefreshCounts = FeedlyAccountDelegate.StatusRefreshCounts(unreadAdded: 3, unreadRemoved: 0, starredAdded: 0, starredRemoved: 0)
		summary.statusesSent = 1
		summary.feedListChanges = FeedlyAccountDelegate.FeedListChanges(foldersAdded: 0, foldersRemoved: 0, feedsAdded: 5, feedsRemoved: 0, feedsRenamed: 0)
		#expect(FeedlyAccountDelegate.refreshAllMessage(summary: summary) == "1 article downloaded, 2 new from feed refresh, 3 marked unread, 1 status sent, 5 feeds added")
	}
}
