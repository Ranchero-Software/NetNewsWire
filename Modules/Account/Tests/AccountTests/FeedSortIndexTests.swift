//
//  FeedSortIndexTests.swift
//  AccountTests
//
//  Created by Claude on 5/13/26.
//

import XCTest
@testable import Account

@MainActor final class FeedSortIndexTests: XCTestCase {

	private var account: Account!

	override func setUp() async throws {
		account = TestAccountManager.shared.createAccount(type: .onMyMac, transport: TestTransport())
	}

	override func tearDown() async throws {
		TestAccountManager.shared.deleteAccount(account)
		account = nil
	}

	func testNewFeedHasZeroSortIndex() {
		let feed = account.createFeed(with: "Example", url: "https://example.com/feed", feedID: "https://example.com/feed", homePageURL: nil)
		XCTAssertEqual(feed.sortIndex, 0)
	}

	func testSettingSortIndex() {
		let feed = account.createFeed(with: "Example", url: "https://example.com/feed", feedID: "https://example.com/feed", homePageURL: nil)
		feed.sortIndex = 42
		XCTAssertEqual(feed.sortIndex, 42)
	}

	func testSettingSortIndexPostsSettingDidChange() {
		let feed = account.createFeed(with: "Example", url: "https://example.com/feed", feedID: "https://example.com/feed", homePageURL: nil)

		let expectation = expectation(forNotification: .feedSettingDidChange, object: feed) { notification in
			(notification.userInfo?[Feed.SettingUserInfoKey] as? Feed.SettingKey) == .sortIndex
		}

		feed.sortIndex = 3
		wait(for: [expectation], timeout: 1.0)
	}

	func testSettingSameSortIndexDoesNotPost() {
		let feed = account.createFeed(with: "Example", url: "https://example.com/feed", feedID: "https://example.com/feed", homePageURL: nil)

		let notExpected = expectation(forNotification: .feedSettingDidChange, object: feed) { notification in
			(notification.userInfo?[Feed.SettingUserInfoKey] as? Feed.SettingKey) == .sortIndex
		}
		notExpected.isInverted = true

		feed.sortIndex = 0 // already 0
		wait(for: [notExpected], timeout: 0.2)
	}
}
