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

class FeedlySendArticleStatusesOperationTests: XCTestCase {
	
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
	
	func testSendEmpty() {
		let service = TestMarkArticlesService()
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
	}
	
	func testSendUnreadSuccess() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .read, flag: false) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unread)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, 0)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendUnreadFailure() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .read, flag: false) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unread)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, statuses.count)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendReadSuccess() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .read, flag: true) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .read)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, 0)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendReadFailure() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .read, flag: true) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .read)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, statuses.count)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendStarredSuccess() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: true) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .saved)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, 0)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendStarredFailure() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: true) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .saved)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, statuses.count)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendUnstarredSuccess() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: false) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .success(())
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unsaved)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, 0)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendUnstarredFailure() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let statuses = articleIds.map { SyncStatus(articleID: $0, key: .starred, flag: false) }
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
		let service = TestMarkArticlesService()
		service.mockResult = .failure(URLError(.timedOut))
		service.parameterTester = { serviceArticleIds, action in
			XCTAssertEqual(serviceArticleIds, articleIds)
			XCTAssertEqual(action, .unsaved)
		}
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let expectedCount = try result.get()
				XCTAssertEqual(expectedCount, statuses.count)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendAllSuccess() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let keys = [ArticleStatus.Key.read, .starred]
		let flags = [true, false]
		let statuses = articleIds.map { articleId -> SyncStatus in
			let key = keys.randomElement()!
			let flag = flags.randomElement()!
			let status = SyncStatus(articleID: articleId, key: key, flag: flag)
			return status
		}
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
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
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, 0)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSendAllFailure() {
		let articleIds = Set((0..<100).map { "feed/0/article/\($0)" })
		let keys = [ArticleStatus.Key.read, .starred]
		let flags = [true, false]
		let statuses = articleIds.map { articleId -> SyncStatus in
			let key = keys.randomElement()!
			let flag = flags.randomElement()!
			let status = SyncStatus(articleID: articleId, key: key, flag: flag)
			return status
		}
		
		let insertExpectation = expectation(description: "Inserted Statuses")
		container.database.insertStatuses(statuses) { error in
			XCTAssertNil(error)
			insertExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 2)
		
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
		
		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
		
		let didFinishExpectation = expectation(description: "Did Finish")
		send.completionBlock = { _ in
			didFinishExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(send)
		
		waitForExpectations(timeout: 2)
		
		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
		container.database.selectPendingCount { result in
			do {
				let statusCount = try result.get()
				XCTAssertEqual(statusCount, statuses.count)
				selectPendingCountExpectation.fulfill()
			} catch {
				XCTFail("Error unwrapping database result: \(error)")
			}
		}
		waitForExpectations(timeout: 2)
	}
}
