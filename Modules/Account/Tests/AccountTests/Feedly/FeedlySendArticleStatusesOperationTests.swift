//
//  FeedlySendArticleStatusesOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 25/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import SyncDatabase
import Articles
import RSCore

@MainActor final class FeedlySendArticleStatusesOperationTests: XCTestCase {

	private var account: Account!
	private let support = FeedlyTestSupport()
	private var container: FeedlyTestSupport.TestDatabaseContainer!

	override func setUp() {
		super.setUp()
		account = support.makeTestAccount()
		container = support.makeTestDatabaseContainer()
	}

	override func tearDown() {
		container = nil
		if let account = account {
			support.destroy(account)
		}
		super.tearDown()
	}

	func testSendEmpty() async {
		let service = TestMarkArticlesService()
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)
	}

	func testSendUnreadSuccess() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .read, flag: false) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unread)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		MainThreadOperationQueue.shared.add(send)
		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, 0)
	}

	func testSendUnreadFailure() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .read, flag: false) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unread)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, statuses.count)
	}

	func testSendReadSuccess() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .read, flag: true) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .read)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, 0)
	}

	func testSendReadFailure() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .read, flag: true) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .read)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, statuses.count)
	}

	func testSendStarredSuccess() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: true) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .saved)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, 0)
	}

	func testSendStarredFailure() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: true) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .saved)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, statuses.count)
	}

	func testSendUnstarredSuccess() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: false) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unsaved)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, 0)
	}

	func testSendUnstarredFailure() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = Set(articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: false) })

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unsaved)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, statuses.count)
	}

	func testSendAllSuccess() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let keys = [SyncStatus.Key.read, .starred]
		let flags = [true, false]
		let statuses = Set(articleIds.map { articleId -> SyncStatus in
			let key = keys.randomElement()!
			let flag = flags.randomElement()!
			let status = SyncStatus(articleID: articleId, key: key, flag: flag)
			return status
		})

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			let syncStatuses: [SyncStatus]
			switch action {
			case .read:
				syncStatuses = statuses.filter { $0.key == .read && $0.flag == true }
			case .unread:
				syncStatuses = statuses.filter { $0.key == .read && $0.flag == false }
			case .saved:
				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == true }
			case .unsaved:
				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == false }
			}
			let expectedArticleIds = Set(syncStatuses.map { $0.articleID })
			XCTAssertEqual(serviceArticleIds, expectedArticleIds)
		}
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, 0)
	}

	func testSendAllFailure() async throws {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let keys = [SyncStatus.Key.read, .starred]
		let flags = [true, false]
		let statuses = Set(articleIds.map { articleId -> SyncStatus in
			let key = keys.randomElement()!
			let flag = flags.randomElement()!
			let status = SyncStatus(articleID: articleId, key: key, flag: flag)
			return status
		})

		try await container.database.insertStatuses(statuses)

		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			let syncStatuses: [SyncStatus]
			switch action {
			case .read:
				syncStatuses = statuses.filter { $0.key == .read && $0.flag == true }
			case .unread:
				syncStatuses = statuses.filter { $0.key == .read && $0.flag == false }
			case .saved:
				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == true }
			case .unsaved:
				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == false }
			}
			let expectedArticleIds = Set(syncStatuses.map { $0.articleID })
			XCTAssertEqual(serviceArticleIds, expectedArticleIds)
		}

		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service)

		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}

		MainThreadOperationQueue.shared.add(send)

		await fulfillment(of: [didFinishExpectation], timeout: 2)

		let statusCount = try await container.database.selectPendingCount()
		XCTAssertEqual(statusCount, statuses.count)
	}
}
