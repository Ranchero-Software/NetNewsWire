//
//  FeedlySyncUnreadStatusesOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 29/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class FeedlySyncUnreadStatusesOperationTests: XCTestCase {
	
	private var account: Account!
	private let support = FeedlyTestSupport()
	
	override func setUp() {
		super.setUp()
		account = support.makeTestAccount()
	}
	
	override func tearDown() {
		if let account = account {
			support.destroy(account)
		}
		super.tearDown()
	}
	
	func testIngestsOnePageSuccess() {
		let service = TestGetStreamIdsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		let ids = [UUID().uuidString]
		service.mockResult = .success(FeedlyStreamIds(continuation: nil, ids: ids))
		
		let getStreamIdsExpectation = expectation(description: "Did Get Page of Stream Ids")
		getStreamIdsExpectation.expectedFulfillmentCount = 1
		
		service.getStreamIdsExpectation = getStreamIdsExpectation
		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertNil(serviceNewerThan)
			XCTAssertNil(continuation)
			XCTAssertEqual(serviceUnreadOnly, true)
		}
		
		let syncUnreads = FeedlySyncUnreadStatusesOperation(account: account, resource: resource, service: service, newerThan: nil, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		syncUnreads.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(syncUnreads)
		
		waitForExpectations(timeout: 2)
		
		let expectedArticleIds = Set(ids)
		let unreadArticleIds = account.fetchUnreadArticleIDs()
		let missingIds = expectedArticleIds.subtracting(unreadArticleIds)
		XCTAssertTrue(missingIds.isEmpty, "These article ids were not marked as unread.")
	}
	
	func testIngestsOnePageFailure() {
		let service = TestGetStreamIdsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		
		service.mockResult = .failure(URLError(.timedOut))
		
		let getStreamIdsExpectation = expectation(description: "Did Get Page of Stream Contents")
		getStreamIdsExpectation.expectedFulfillmentCount = 1
		
		service.getStreamIdsExpectation = getStreamIdsExpectation
		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertNil(serviceNewerThan)
			XCTAssertNil(continuation)
			XCTAssertEqual(serviceUnreadOnly, true)
		}
		
		let syncUnreads = FeedlySyncUnreadStatusesOperation(account: account, resource: resource, service: service, newerThan: nil, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		syncUnreads.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(syncUnreads)
		
		waitForExpectations(timeout: 2)
		
		let unreadArticleIds = account.fetchUnreadArticleIDs()
		XCTAssertTrue(unreadArticleIds.isEmpty)
	}
	
	func testIngestsManyPagesSuccess() {
		let service = TestGetPagedStreamIdsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		
		let continuations = (1...10).map { "\($0)" }
		service.addAtLeastOnePage(for: resource, continuations: continuations, numberOfEntriesPerPage: 1000)
		
		let getStreamIdsExpectation = expectation(description: "Did Get Page of Stream Contents")
		getStreamIdsExpectation.expectedFulfillmentCount = 1 + continuations.count
		
		var remainingContinuations = Set(continuations)
		let getStreamPageExpectation = expectation(description: "Did Request Page")
		getStreamPageExpectation.expectedFulfillmentCount = 1 + continuations.count
		
		service.getStreamIdsExpectation = getStreamIdsExpectation
		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertNil(serviceNewerThan)
			XCTAssertEqual(serviceUnreadOnly, true)
			
			if let continuation = continuation {
				XCTAssertTrue(remainingContinuations.contains(continuation))
				remainingContinuations.remove(continuation)
			}
			
			getStreamPageExpectation.fulfill()
		}
		
		let syncUnreads = FeedlySyncUnreadStatusesOperation(account: account, resource: resource, service: service, newerThan: nil, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		syncUnreads.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(syncUnreads)
		
		waitForExpectations(timeout: 2)
		
		// Find statuses inserted.
		let expectedArticleIds = Set(service.pages.values.map { $0.ids }.flatMap { $0 })
		let unreadArticleIds = account.fetchUnreadArticleIDs()
		let missingIds = expectedArticleIds.subtracting(unreadArticleIds)
		XCTAssertTrue(missingIds.isEmpty, "These article ids were not marked as unread.")
	}
}
