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

//class FeedlySendArticleStatusesOperationTests: XCTestCase {
//	
//	private var account: Account!
//	private let support = FeedlyTestSupport()
//	private var container: FeedlyTestSupport.TestDatabaseContainer!
//	
//	override func setUp() {
//		super.setUp()
//		account = support.makeTestAccount()
//		container = support.makeTestDatabaseContainer()
//	}
//	
//	override func tearDown() {
//		container = nil
//		if let account = account {
//			support.destroy(account)
//		}
//		super.tearDown()
//	}
//	
//	func testSendEmpty() {
//		let service = TestMarkArticlesService()
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendUnreadSuccess() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .read, flag: false) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .success(())
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .unread)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, 0)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendUnreadFailure() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .read, flag: false) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .failure(URLError(.timedOut))
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .unread)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, statuses.count)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendReadSuccess() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .read, flag: true) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .success(())
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .read)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, 0)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendReadFailure() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .read, flag: true) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .failure(URLError(.timedOut))
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .read)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, statuses.count)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendStarredSuccess() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .starred, flag: true) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .success(())
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .saved)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, 0)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendStarredFailure() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .starred, flag: true) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .failure(URLError(.timedOut))
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .saved)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, statuses.count)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendUnstarredSuccess() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .starred, flag: false) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .success(())
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .unsaved)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, 0)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendUnstarredFailure() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let statuses = articleIDs.map { SyncStatus(articleID: $0, key: .starred, flag: false) }
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .failure(URLError(.timedOut))
//		service.parameterTester = { serviceArticleIDs, action in
//			XCTAssertEqual(serviceArticleIDs, articleIDs)
//			XCTAssertEqual(action, .unsaved)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let expectedCount = try result.get()
//				XCTAssertEqual(expectedCount, statuses.count)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendAllSuccess() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let keys = [SyncStatus.Key.read, .starred]
//		let flags = [true, false]
//		let statuses = articleIDs.map { articleID -> SyncStatus in
//			let key = keys.randomElement()!
//			let flag = flags.randomElement()!
//			let status = SyncStatus(articleID: articleID, key: key, flag: flag)
//			return status
//		}
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .success(())
//		service.parameterTester = { serviceArticleIDs, action in
//			let syncStatuses: [SyncStatus]
//			switch action {
//			case .read:
//				syncStatuses = statuses.filter { $0.key == .read && $0.flag == true }
//			case .unread:
//				syncStatuses = statuses.filter { $0.key == .read && $0.flag == false }
//			case .saved:
//				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == true }
//			case .unsaved:
//				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == false }
//			}
//			let expectedArticleIDs = Set(syncStatuses.map { $0.articleID })
//			XCTAssertEqual(serviceArticleIDs, expectedArticleIDs)
//		}
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, 0)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testSendAllFailure() {
//		let articleIDs = Set((0..<100).map { "feed/0/article/\($0)" })
//		let keys = [SyncStatus.Key.read, .starred]
//		let flags = [true, false]
//		let statuses = articleIDs.map { articleID -> SyncStatus in
//			let key = keys.randomElement()!
//			let flag = flags.randomElement()!
//			let status = SyncStatus(articleID: articleID, key: key, flag: flag)
//			return status
//		}
//		
//		let insertExpectation = expectation(description: "Inserted Statuses")
//		container.database.insertStatuses(statuses) { error in
//			XCTAssertNil(error)
//			insertExpectation.fulfill()
//		}
//		
//		waitForExpectations(timeout: 2)
//		
//		let service = TestMarkArticlesService()
//		service.mockResult = .failure(URLError(.timedOut))
//		service.parameterTester = { serviceArticleIDs, action in
//			let syncStatuses: [SyncStatus]
//			switch action {
//			case .read:
//				syncStatuses = statuses.filter { $0.key == .read && $0.flag == true }
//			case .unread:
//				syncStatuses = statuses.filter { $0.key == .read && $0.flag == false }
//			case .saved:
//				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == true }
//			case .unsaved:
//				syncStatuses = statuses.filter { $0.key == .starred && $0.flag == false }
//			}
//			let expectedArticleIDs = Set(syncStatuses.map { $0.articleID })
//			XCTAssertEqual(serviceArticleIDs, expectedArticleIDs)
//		}
//		
//		let send = FeedlySendArticleStatusesOperation(database: container.database, service: service, log: support.log)
//		
//		let didFinishExpectation = expectation(description: "Did Finish")
//		send.completionBlock = { _ in
//			didFinishExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(send)
//		
//		waitForExpectations(timeout: 2)
//		
//		let selectPendingCountExpectation = expectation(description: "Did Select Pending Count")
//		container.database.selectPendingCount { result in
//			do {
//				let statusCount = try result.get()
//				XCTAssertEqual(statusCount, statuses.count)
//				selectPendingCountExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping database result: \(error)")
//			}
//		}
//		waitForExpectations(timeout: 2)
//	}
//}
