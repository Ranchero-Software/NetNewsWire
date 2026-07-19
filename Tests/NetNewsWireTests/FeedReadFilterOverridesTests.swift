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

	// MARK: - Empty state

	func testEmptyByDefault() {
		let overrides = FeedReadFilterOverrides()
		XCTAssertNil(overrides.override(accountID: accountID, feedID: feedID))
		XCTAssertFalse(overrides.hasOverride(accountID: accountID, feedID: feedID))
		XCTAssertTrue(overrides.allFeeds().isEmpty)
	}

	// MARK: - Legacy migration

	func testMigratingMapsEveryFeedToHide() {
		let legacy: [String: Set<String>] = [accountID: [feedID, otherFeedID], otherAccountID: [feedID]]
		let overrides = FeedReadFilterOverrides.migrating(legacyFeedsHiding: legacy)

		XCTAssertEqual(overrides.override(accountID: accountID, feedID: feedID), .hide)
		XCTAssertEqual(overrides.override(accountID: accountID, feedID: otherFeedID), .hide)
		XCTAssertEqual(overrides.override(accountID: otherAccountID, feedID: feedID), .hide)
		XCTAssertEqual(overrides.allFeeds().count, 3)
	}

	func testMigratingEmptyLegacyProducesEmptyOverrides() {
		let overrides = FeedReadFilterOverrides.migrating(legacyFeedsHiding: [:])
		XCTAssertTrue(overrides.allFeeds().isEmpty)
	}

	// MARK: - Mutation round-trips

	func testSetAndReadHideOverride() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .hide)

		XCTAssertTrue(overrides.hasOverride(accountID: accountID, feedID: feedID))
		XCTAssertEqual(overrides.override(accountID: accountID, feedID: feedID), .hide)
	}

	func testSetAndReadShowOverride() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .show)

		XCTAssertTrue(overrides.hasOverride(accountID: accountID, feedID: feedID))
		XCTAssertEqual(overrides.override(accountID: accountID, feedID: feedID), .show)
	}

	func testSetOverrideReplacesPreviousValue() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .hide)
		overrides.setOverride(accountID: accountID, feedID: feedID, .show)

		XCTAssertEqual(overrides.override(accountID: accountID, feedID: feedID), .show)
		XCTAssertEqual(overrides.allFeeds().count, 1)
	}

	func testClearOverrideRemovesOnlyThatFeed() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .hide)
		overrides.setOverride(accountID: accountID, feedID: otherFeedID, .show)

		overrides.clearOverride(accountID: accountID, feedID: feedID)

		XCTAssertFalse(overrides.hasOverride(accountID: accountID, feedID: feedID))
		XCTAssertEqual(overrides.override(accountID: accountID, feedID: otherFeedID), .show)
	}

	// MARK: - Empty-account cleanup

	func testClearingLastFeedRemovesAccount() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .hide)
		overrides.clearOverride(accountID: accountID, feedID: feedID)

		XCTAssertTrue(overrides.allFeeds().isEmpty)
		// A cleaned-up account round-trips identically to a never-used one.
		XCTAssertEqual(overrides, FeedReadFilterOverrides())
	}

	func testClearAllRemovesOnlyGivenAccount() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .hide)
		overrides.setOverride(accountID: otherAccountID, feedID: otherFeedID, .show)

		overrides.clearAll(accountID: accountID)

		XCTAssertFalse(overrides.hasOverride(accountID: accountID, feedID: feedID))
		XCTAssertEqual(overrides.override(accountID: otherAccountID, feedID: otherFeedID), .show)
		XCTAssertEqual(overrides.allFeeds().count, 1)
	}

	func testClearOverrideForMissingFeedIsNoOp() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .hide)

		overrides.clearOverride(accountID: accountID, feedID: otherFeedID)
		overrides.clearOverride(accountID: otherAccountID, feedID: feedID)

		XCTAssertEqual(overrides.override(accountID: accountID, feedID: feedID), .hide)
		XCTAssertEqual(overrides.allFeeds().count, 1)
	}

	// MARK: - Serialization

	func testSerializationRoundTrip() {
		var overrides = FeedReadFilterOverrides()
		overrides.setOverride(accountID: accountID, feedID: feedID, .hide)
		overrides.setOverride(accountID: otherAccountID, feedID: otherFeedID, .show)

		let restored = FeedReadFilterOverrides(data: overrides.data)
		XCTAssertEqual(restored, overrides)
	}

	func testInitWithNilDataProducesEmptyOverrides() {
		let overrides = FeedReadFilterOverrides(data: nil)
		XCTAssertEqual(overrides, FeedReadFilterOverrides())
	}

	func testInitWithMalformedDataProducesEmptyOverrides() {
		let garbage = Data("not valid json".utf8)
		let overrides = FeedReadFilterOverrides(data: garbage)
		XCTAssertEqual(overrides, FeedReadFilterOverrides())
	}
}
