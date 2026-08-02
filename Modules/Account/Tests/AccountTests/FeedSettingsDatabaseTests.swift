//
//  FeedSettingsDatabaseTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 8/2/26.
//

import Foundation
import Testing
@testable import Account

struct FeedSettingsDatabaseTests {

	@Test func feedIDColumnIsUpdatable() {
		let database = makeDatabase()
		let feedURL = "https://example.com/feed.xml"
		let canonicalFeedID = "feed/\(feedURL)"

		database.ensureFeedExists(feedURL, feedID: feedURL)
		database.setString(canonicalFeedID, for: feedURL, column: .feedID)

		#expect(database.allRows()[feedURL]?.feedID == canonicalFeedID)
	}

	@Test func ensureFeedExistsDoesNotReplaceFeedID() {
		let database = makeDatabase()
		let feedURL = "https://example.com/feed.xml"
		let canonicalFeedID = "feed/\(feedURL)"

		database.ensureFeedExists(feedURL, feedID: canonicalFeedID)
		database.ensureFeedExists(feedURL, feedID: feedURL)

		#expect(database.allRows()[feedURL]?.feedID == canonicalFeedID)
	}

	private func makeDatabase() -> FeedSettingsDatabase {
		FeedSettingsDatabase(databasePath: ":memory:")
	}
}
