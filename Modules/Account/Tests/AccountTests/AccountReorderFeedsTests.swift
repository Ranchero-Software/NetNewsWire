//
//  AccountReorderFeedsTests.swift
//  AccountTests
//
//  Created by Claude on 5/13/26.
//

import XCTest
@testable import Account

@MainActor final class AccountReorderFeedsTests: XCTestCase {

	private var account: Account!

	override func setUp() async throws {
		account = TestAccountManager.shared.createAccount(type: .onMyMac, transport: TestTransport())
	}

	override func tearDown() async throws {
		TestAccountManager.shared.deleteAccount(account)
		account = nil
	}

	func testReorderAssignsSequentialSortIndexes() async throws {
		let a = makeFeed("a")
		let b = makeFeed("b")
		let c = makeFeed("c")

		try await account.reorderFeeds([c, a, b], in: account)

		XCTAssertEqual(c.sortIndex, 0)
		XCTAssertEqual(a.sortIndex, 1)
		XCTAssertEqual(b.sortIndex, 2)
	}

	func testReorderingAgainRenumbers() async throws {
		let a = makeFeed("a")
		let b = makeFeed("b")

		try await account.reorderFeeds([b, a], in: account)
		XCTAssertEqual(b.sortIndex, 0)
		XCTAssertEqual(a.sortIndex, 1)

		try await account.reorderFeeds([a, b], in: account)
		XCTAssertEqual(a.sortIndex, 0)
		XCTAssertEqual(b.sortIndex, 1)
	}

	func testReorderPostsChildrenDidChange() async throws {
		let a = makeFeed("a")
		let b = makeFeed("b")

		let expectation = expectation(forNotification: .ChildrenDidChange, object: account, handler: nil)
		try await account.reorderFeeds([b, a], in: account)
		await fulfillment(of: [expectation], timeout: 1.0)
	}

	func testReorderedMovingBefore() {
		let a = makeFeed("a")
		let b = makeFeed("b")
		let c = makeFeed("c")
		let feeds = [a, b, c]

		XCTAssertEqual(feeds.reordered(moving: c, before: a).map(\.feedID), [c, a, b].map(\.feedID))
		XCTAssertEqual(feeds.reordered(moving: a, before: c).map(\.feedID), [b, a, c].map(\.feedID))
		XCTAssertEqual(feeds.reordered(moving: a, before: nil).map(\.feedID), [b, c, a].map(\.feedID))
		XCTAssertEqual(feeds.reordered(moving: b, before: b).map(\.feedID), [a, b, c].map(\.feedID)) // dropping before itself: no change
		XCTAssertEqual(feeds.reordered(moving: c, before: nil).map(\.feedID), [a, b, c].map(\.feedID)) // already last: no change
	}

	func testReorderFeedsInFolder() async throws {
		let folder = account.ensureFolder(with: "Folder")!
		let a = account.createFeed(with: "A", url: "https://a.example/feed", feedID: "https://a.example/feed", homePageURL: nil)
		let b = account.createFeed(with: "B", url: "https://b.example/feed", feedID: "https://b.example/feed", homePageURL: nil)
		folder.addFeedToTreeAtTopLevel(a)
		folder.addFeedToTreeAtTopLevel(b)

		try await account.reorderFeeds([b, a], in: folder)

		XCTAssertEqual(b.sortIndex, 0)
		XCTAssertEqual(a.sortIndex, 1)
	}

	// MARK: - Helpers

	@discardableResult
	private func makeFeed(_ id: String) -> Feed {
		let url = "https://\(id).example/feed"
		let feed = account.createFeed(with: id.uppercased(), url: url, feedID: url, homePageURL: nil)
		account.addFeedToTreeAtTopLevel(feed)
		return feed
	}
}
