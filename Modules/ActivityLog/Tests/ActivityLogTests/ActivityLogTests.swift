//
//  ActivityLogTests.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

import Testing
import Foundation
@testable import ActivityLog

@Suite @MainActor struct ActivityLogTests {

	@Test func createActivityAssignsIncrementingIDs() {
		let activityLog = ActivityLog()

		let id1 = activityLog.createActivity(owner: .feedFinder, kind: .findFeed(urlString: "https://example.com"))
		let id2 = activityLog.createActivity(owner: .feedFinder, kind: .findFeed(urlString: "https://example.org"))

		#expect(id2 == id1 + 1)
		#expect(activityLog.pendingActivities.count == 2)
	}

	@Test func createdActivityIsPending() {
		let activityLog = ActivityLog()

		activityLog.createActivity(owner: .feedFinder, kind: .findFeed(urlString: "https://example.com"))

		#expect(activityLog.pendingActivities[0].state == .pending)
		#expect(activityLog.pendingActivities[0].startDate == nil)
		#expect(activityLog.runningActivities.isEmpty)
	}

	@Test func didStartByKind() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		activityLog.createActivity(owner: owner, kind: .sendArticleStatuses)
		activityLog.didStart(owner, kind: .sendArticleStatuses)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities.count == 1)
		#expect(activityLog.runningActivities[0].state == .running)
		#expect(activityLog.runningActivities[0].startDate != nil)
	}

	@Test func didCompleteByKind() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		activityLog.createActivity(owner: owner, kind: .sendArticleStatuses)
		activityLog.didStart(owner, kind: .sendArticleStatuses)
		activityLog.didComplete(owner, kind: .sendArticleStatuses)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .completed)
		#expect(activityLog.completedActivities[0].endDate != nil)
	}

	@Test func logCompletedActivityCompletesWithoutDuration() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		activityLog.logCompletedActivity(owner: owner, kind: .sendArticleStatuses, message: "Done")

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)

		let activity = activityLog.completedActivities[0]
		#expect(activity.state == .completed)
		#expect(activity.completionMessage == "Done")
		#expect(activity.endDate != nil)
		// No start timestamp is recorded, so no duration is shown.
		#expect(activity.startDate == nil)
		#expect(activity.formattedDuration == nil)
	}

	@Test func logActivityReturnsResultAndCompletesWithMessage() async {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		let result = await activityLog.logActivity(owner: owner, kind: .sendArticleStatuses, successMessage: { "sent \($0)" }, {
			42
		})

		#expect(result == 42)
		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)

		let activity = activityLog.completedActivities[0]
		#expect(activity.state == .completed)
		#expect(activity.completionMessage == "sent 42")
		// Unlike logCompletedActivity, the timed wrapper starts the activity, so it has a duration.
		#expect(activity.startDate != nil)
		#expect(activity.endDate != nil)
	}

	@Test func logActivityRecordsFailureAndRethrows() async {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")
		struct TestError: Error {}

		await #expect(throws: TestError.self) {
			try await activityLog.logActivity(owner: owner, kind: .refreshFeedList) {
				throw TestError()
			}
		}

		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .failed)
		#expect(activityLog.completedActivities[0].error != nil)
	}

	@Test func logActivitySuppressesDurationWhenNotSignificant() async {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		await activityLog.logActivity(owner: owner, kind: .sendArticleStatuses, durationIsSignificant: { _ in false }, {
		})

		let activity = activityLog.completedActivities[0]
		#expect(activity.state == .completed)
		#expect(activity.startDate != nil)
		#expect(activity.formattedDuration == nil)
	}

	@Test func logActivitySyncOverloadCompletes() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		let result = activityLog.logActivity(owner: owner, kind: .vacuumDatabase) {
			"done"
		}

		#expect(result == "done")
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .completed)
	}

	@Test func logActivitySyncOverloadRecordsFailureAndRethrows() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")
		struct TestError: Error {}

		#expect(throws: TestError.self) {
			try activityLog.logActivity(owner: owner, kind: .vacuumDatabase) {
				throw TestError()
			}
		}

		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .failed)
		#expect(activityLog.completedActivities[0].error != nil)
	}

	@Test func didFailByKind() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")
		let error = NSError(domain: "test", code: 1)

		activityLog.createActivity(owner: owner, kind: .refreshFeedList)
		activityLog.didStart(owner, kind: .refreshFeedList)
		activityLog.didFail(owner, kind: .refreshFeedList, error: error)

		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .failed)
		#expect(activityLog.completedActivities[0].error != nil)
		#expect(activityLog.completedActivities[0].endDate != nil)
	}

	@Test func didStartByID() {
		let activityLog = ActivityLog()

		let id = activityLog.createActivity(owner: .feedImageDownloader, kind: .downloadFeedImage(feedURL: "Daring Fireball"))
		activityLog.didStart(id: id)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities[0].state == .running)
	}

	@Test func didCompleteByID() {
		let activityLog = ActivityLog()

		let id = activityLog.createActivity(owner: .feedImageDownloader, kind: .downloadFeedImage(feedURL: "Daring Fireball"))
		activityLog.didStart(id: id)
		activityLog.didComplete(id: id)

		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .completed)
	}

	@Test func didFailByID() {
		let activityLog = ActivityLog()
		let error = NSError(domain: "test", code: 1)

		let id = activityLog.createActivity(owner: .feedFinder, kind: .findFeed(urlString: "https://example.com"))
		activityLog.didStart(id: id)
		activityLog.didFail(id: id, error: error)

		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .failed)
	}

	@Test func didCompleteByKindStartsPendingActivity() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		// Complete without an explicit didStart — the pending activity should be
		// promoted and completed, not orphaned.
		activityLog.createActivity(owner: owner, kind: .sendArticleStatuses)
		activityLog.didComplete(owner, kind: .sendArticleStatuses)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .completed)
		#expect(activityLog.completedActivities[0].startDate == nil) // promoted without a timestamp
		#expect(activityLog.completedActivities[0].endDate != nil)
	}

	@Test func didFailByKindStartsPendingActivity() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")
		let error = NSError(domain: "test", code: 1)

		activityLog.createActivity(owner: owner, kind: .refreshFeedList)
		activityLog.didFail(owner, kind: .refreshFeedList, error: error)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .failed)
		#expect(activityLog.completedActivities[0].error != nil)
	}

	@Test func didCompleteByIDStartsPendingActivity() {
		let activityLog = ActivityLog()

		let id = activityLog.createActivity(owner: .feedImageDownloader, kind: .downloadFeedImage(feedURL: "Daring Fireball"))
		activityLog.didComplete(id: id)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .completed)
		#expect(activityLog.completedActivities[0].startDate == nil)
	}

	@Test func didFailByIDStartsPendingActivity() {
		let activityLog = ActivityLog()
		let error = NSError(domain: "test", code: 1)

		let id = activityLog.createActivity(owner: .feedFinder, kind: .findFeed(urlString: "https://example.com"))
		activityLog.didFail(id: id, error: error)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)
		#expect(activityLog.completedActivities[0].state == .failed)
	}

	@Test func completedActivitiesTrimming() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		for i in 0..<510 {
			let kind = ActivityKind.refreshFeedContent(feedURL: "Feed \(i)")
			activityLog.createActivity(owner: owner, kind: kind)
			activityLog.didStart(owner, kind: kind)
			activityLog.didComplete(owner, kind: kind)
		}

		#expect(activityLog.completedActivities.count == 500)
		// Oldest entries should have been removed.
		#expect(activityLog.completedActivities[0].kind == .refreshFeedContent(feedURL: "Feed 10"))
		#expect(activityLog.completedActivities[499].kind == .refreshFeedContent(feedURL: "Feed 509"))
	}

	@Test func pendingActivitiesForOwner() {
		let activityLog = ActivityLog()
		let owner1 = ActivityOwner.account(accountID: "account1", displayName: "Account One")
		let owner2 = ActivityOwner.account(accountID: "account2", displayName: "Account Two")

		activityLog.createActivity(owner: owner1, kind: .sendArticleStatuses)
		activityLog.createActivity(owner: owner2, kind: .sendArticleStatuses)
		activityLog.createActivity(owner: owner1, kind: .refreshFeedList)

		#expect(activityLog.pendingActivities(for: owner1).count == 2)
		#expect(activityLog.pendingActivities(for: owner2).count == 1)
	}

	@Test func multipleKindsForSameOwner() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		activityLog.createActivity(owner: owner, kind: .sendArticleStatuses)
		activityLog.createActivity(owner: owner, kind: .refreshArticleStatuses)
		activityLog.createActivity(owner: owner, kind: .refreshFeedList)

		activityLog.didStart(owner, kind: .sendArticleStatuses)
		activityLog.didComplete(owner, kind: .sendArticleStatuses)

		#expect(activityLog.pendingActivities.count == 2)
		#expect(activityLog.runningActivities.isEmpty)
		#expect(activityLog.completedActivities.count == 1)

		activityLog.didStart(owner, kind: .refreshArticleStatuses)
		activityLog.didStart(owner, kind: .refreshFeedList)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities.count == 2)
		#expect(activityLog.runningActivities.allSatisfy { $0.state == .running })
	}

	@Test func detailIsPreserved() {
		let activityLog = ActivityLog()

		activityLog.createActivity(owner: .account(accountID: "account1", displayName: "Account One"), kind: .sendArticleStatuses, detail: "42 statuses")

		#expect(activityLog.pendingActivities[0].detail == "42 statuses")
	}

	@Test func startIfNeededStartsPendingWithoutTimestamp() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		activityLog.createActivity(owner: owner, kind: .refreshFeedList)
		activityLog.startIfNeeded(owner, kind: .refreshFeedList)

		#expect(activityLog.pendingActivities.isEmpty)
		#expect(activityLog.runningActivities.count == 1)
		#expect(activityLog.runningActivities[0].state == .running)
		#expect(activityLog.runningActivities[0].startDate == nil) // promoted without a timestamp
	}

	@Test func startIfNeededDoesNothingWhenAlreadyRunning() {
		let activityLog = ActivityLog()
		let owner = ActivityOwner.account(accountID: "account1", displayName: "Account One")

		activityLog.createActivity(owner: owner, kind: .refreshFeedList)
		activityLog.didStart(owner, kind: .refreshFeedList)
		let startDate = activityLog.runningActivities[0].startDate

		activityLog.startIfNeeded(owner, kind: .refreshFeedList)

		#expect(activityLog.runningActivities.count == 1)
		#expect(activityLog.runningActivities[0].startDate == startDate) // unchanged
	}

	@Test func nextTaskNumberStringIncrements() {
		let activityLog = ActivityLog()

		#expect(activityLog.nextTaskNumberString() == "#1")
		#expect(activityLog.nextTaskNumberString() == "#2")
		#expect(activityLog.nextTaskNumberString() == "#3")
	}

	@Test func kindDisplayNameForSimpleKind() {
		#expect(ActivityKind.refreshAll.displayName(detail: nil) == "Refresh all")
	}

	@Test func kindDisplayNameUsesDetailForFeedContent() {
		let kind = ActivityKind.refreshFeedContent(feedURL: "https://example.com/feed.json")
		#expect(kind.displayName(detail: "My Feed") == "Refreshing feed: My Feed")
		#expect(kind.displayName(detail: nil) == "Refreshing feed: https://example.com/feed.json")
	}

	@Test func kindDisplayNameForURLKind() {
		#expect(ActivityKind.findFeed(urlString: "https://example.com").displayName(detail: nil) == "Finding feed https://example.com")
	}

	@Test func formattedDurationUnderTenSecondsHasTwoDecimals() {
		#expect(Activity.formattedDuration(0.456) == "0.46s")
		#expect(Activity.formattedDuration(9.999) == "10.00s")
	}

	@Test func formattedDurationUnderOneMinuteHasOneDecimal() {
		#expect(Activity.formattedDuration(10.0) == "10.0s")
		#expect(Activity.formattedDuration(12.34) == "12.3s")
	}

	@Test func formattedDurationOneMinuteOrMoreUsesMinutesAndSeconds() {
		#expect(Activity.formattedDuration(60.0) == "1m 0s")
		#expect(Activity.formattedDuration(135.0) == "2m 15s")
	}
}
