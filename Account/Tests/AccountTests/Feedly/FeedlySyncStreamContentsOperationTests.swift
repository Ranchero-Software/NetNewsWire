//
//  FeedlySyncStreamContentsOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 26/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//class FeedlySyncStreamContentsOperationTests: XCTestCase {
//	
//	private var account: Account!
//	private let support = FeedlyTestSupport()
//	
//	override func setUp() {
//		super.setUp()
//		account = support.makeTestAccount()
//	}
//	
//	override func tearDown() {
//		if let account = account {
//			support.destroy(account)
//		}
//		super.tearDown()
//	}
//	
//	func testIngestsOnePageSuccess() throws {
//		let service = TestGetStreamContentsService()
//		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
//		let newerThan: Date? = Date(timeIntervalSinceReferenceDate: 0)
//		let items = service.makeMockFeedlyEntryItem()
//		service.mockResult = .success(FeedlyStream(id: resource.id, updated: nil, continuation: nil, items: items))
//		
//		let getStreamContentsExpectation = expectation(description: "Did Get Page of Stream Contents")
//		getStreamContentsExpectation.expectedFulfillmentCount = 1
//		
//		service.getStreamContentsExpectation = getStreamContentsExpectation
//		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
//			XCTAssertEqual(serviceResource.id, resource.id)
//			XCTAssertEqual(serviceNewerThan, newerThan)
//			XCTAssertNil(continuation)
//			XCTAssertNil(serviceUnreadOnly)
//		}
//		
//		let syncStreamContents = FeedlySyncStreamContentsOperation(account: account, resource: resource, service: service, isPagingEnabled: true, newerThan: newerThan, log: support.log)
//		
//		let completionExpectation = expectation(description: "Did Finish")
//		syncStreamContents.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(syncStreamContents)
//		
//		waitForExpectations(timeout: 2)
//		
//		let expectedArticleIDs = Set(items.map { $0.id })
//		let expectedArticles = try account.fetchArticles(.articleIDs(expectedArticleIDs))
//		XCTAssertEqual(expectedArticles.count, expectedArticleIDs.count, "Did not fetch all the articles.")
//	}
//	
//	func testIngestsOnePageFailure() {
//		let service = TestGetStreamContentsService()
//		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
//		let newerThan: Date? = Date(timeIntervalSinceReferenceDate: 0)
//		
//		service.mockResult = .failure(URLError(.timedOut))
//		
//		let getStreamContentsExpectation = expectation(description: "Did Get Page of Stream Contents")
//		getStreamContentsExpectation.expectedFulfillmentCount = 1
//		
//		service.getStreamContentsExpectation = getStreamContentsExpectation
//		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
//			XCTAssertEqual(serviceResource.id, resource.id)
//			XCTAssertEqual(serviceNewerThan, newerThan)
//			XCTAssertNil(continuation)
//			XCTAssertNil(serviceUnreadOnly)
//		}
//		
//		let syncStreamContents = FeedlySyncStreamContentsOperation(account: account, resource: resource, service: service, isPagingEnabled: true, newerThan: newerThan, log: support.log)
//		
//		let completionExpectation = expectation(description: "Did Finish")
//		syncStreamContents.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(syncStreamContents)
//		
//		waitForExpectations(timeout: 2)
//	}
//	
//	func testIngestsManyPagesSuccess() throws {
//		let service = TestGetPagedStreamContentsService()
//		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
//		let newerThan: Date? = Date(timeIntervalSinceReferenceDate: 0)
//		
//		let continuations = (1...10).map { "\($0)" }
//		service.addAtLeastOnePage(for: resource, continuations: continuations, numberOfEntriesPerPage: 1000)
//		
//		let getStreamContentsExpectation = expectation(description: "Did Get Page of Stream Contents")
//		getStreamContentsExpectation.expectedFulfillmentCount = 1 + continuations.count
//		
//		var remainingContinuations = Set(continuations)
//		let getStreamPageExpectation = expectation(description: "Did Request Page")
//		getStreamPageExpectation.expectedFulfillmentCount = 1 + continuations.count
//		
//		service.getStreamContentsExpectation = getStreamContentsExpectation
//		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
//			XCTAssertEqual(serviceResource.id, resource.id)
//			XCTAssertEqual(serviceNewerThan, newerThan)
//			XCTAssertNil(serviceUnreadOnly)
//			
//			if let continuation = continuation {
//				XCTAssertTrue(remainingContinuations.contains(continuation))
//				remainingContinuations.remove(continuation)
//			}
//			
//			getStreamPageExpectation.fulfill()
//		}
//		
//		let syncStreamContents = FeedlySyncStreamContentsOperation(account: account, resource: resource, service: service, isPagingEnabled: true, newerThan: newerThan, log: support.log)
//		
//		let completionExpectation = expectation(description: "Did Finish")
//		syncStreamContents.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(syncStreamContents)
//		
//		waitForExpectations(timeout: 30)
//		
//		// Find articles inserted.
//		let articleIDs = Set(service.pages.values.map { $0.items }.flatMap { $0 }.map { $0.id })
//		let articles = try account.fetchArticles(.articleIDs(articleIDs))
//		XCTAssertEqual(articleIDs.count, articles.count)
//	}
//}
