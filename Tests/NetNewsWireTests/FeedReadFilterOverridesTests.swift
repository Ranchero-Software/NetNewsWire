//
//  FeedReadFilterOverridesTests.swift
//  NetNewsWire
//
//  Created by Paul on 7/19/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import XCTest

@testable import NetNewsWire

final class FeedReadFilterOverridesTests: XCTestCase {

	private let accountID = "account1"
	private let otherAccountID = "account2"
	private let feedID = "feed1"
	private let otherFeedID = "feed2"

	func testMigratingMapsEveryFeedToHide() {
		let legacy: [String: Set<String>] = [accountID: [feedID, otherFeedID], otherAccountID: [feedID]]
		let overrides = FeedReadFilterOverrides.migrating(legacyFeedsHiding: legacy)

		XCTAssertEqual(overrides.override(accountID: accountID, feedID: feedID), .hide)
		XCTAssertEqual(overrides.override(accountID: accountID, feedID: otherFeedID), .hide)
		XCTAssertEqual(overrides.override(accountID: otherAccountID, feedID: feedID), .hide)
	}

	func testClearingLastOverrideLeavesNoEmptyAccount() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(.hide, accountID: accountID, feedID: feedID)
		overrides.clearOverride(accountID: accountID, feedID: feedID)

		XCTAssertNil(overrides.override(accountID: accountID, feedID: feedID))
		// An emptied account compares equal to a never-used one.
		XCTAssertEqual(overrides, FeedReadFilterOverrides())
	}

	func testClearAllRemovesOnlyGivenAccount() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(.hide, accountID: accountID, feedID: feedID)
		overrides.setOverride(.show, accountID: otherAccountID, feedID: otherFeedID)

		overrides.clearAll(accountID: accountID)

		XCTAssertNil(overrides.override(accountID: accountID, feedID: feedID))
		XCTAssertEqual(overrides.override(accountID: otherAccountID, feedID: otherFeedID), .show)
	}

	func testRemoveAllWhereDropsOnlyMatchingFeeds() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(.hide, accountID: accountID, feedID: feedID)
		overrides.setOverride(.show, accountID: accountID, feedID: otherFeedID)
		overrides.setOverride(.hide, accountID: otherAccountID, feedID: feedID)

		overrides.removeAll { accountID, _ in accountID == otherAccountID }
		overrides.removeAll { _, feedID in feedID == otherFeedID }

		var expected = FeedReadFilterOverrides()
		expected.setOverride(.hide, accountID: accountID, feedID: feedID)
		XCTAssertEqual(overrides, expected)
	}

	func testSerializationRoundTrip() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(.hide, accountID: accountID, feedID: feedID)
		overrides.setOverride(.show, accountID: otherAccountID, feedID: otherFeedID)

		XCTAssertEqual(FeedReadFilterOverrides(data: overrides.data), overrides)
	}

	func testMalformedDataProducesEmptyOverrides() {
		XCTAssertEqual(FeedReadFilterOverrides(data: Data("not valid json".utf8)), FeedReadFilterOverrides())
	}
}
