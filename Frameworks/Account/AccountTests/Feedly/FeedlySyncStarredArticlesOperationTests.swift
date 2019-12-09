//
//  FeedlySyncStarredArticlesOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class FeedlySyncStarredArticlesOperationTests: XCTestCase {
	
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
		let service = TestGetStreamContentsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		let items = service.makeMockFeedlyEntryItem()
		service.mockResult = .success(FeedlyStream(id: resource.id, updated: nil, continuation: nil, items: items))
		
		let getStreamContentsExpectation = expectation(description: "Did Get Page of Stream Contents")
		getStreamContentsExpectation.expectedFulfillmentCount = 1
		
		service.getStreamContentsExpectation = getStreamContentsExpectation
		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertNil(serviceNewerThan)
			XCTAssertNil(continuation)
			XCTAssertNil(serviceUnreadOnly)
		}
		
		let syncStarred = FeedlySyncStarredArticlesOperation(account: account, resource: resource, service: service, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		syncStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(syncStarred)
		
		waitForExpectations(timeout: 2)
		
		let expectedArticleIds = Set(items.map { $0.id })
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { starredArticleIds in
			let missingIds = expectedArticleIds.subtracting(starredArticleIds)
			XCTAssertTrue(missingIds.isEmpty, "These article ids were not marked as starred.")
			
			// Fetch articles directly because account.fetchArticles(.starred) fetches starred articles for feeds subscribed to.
			let expectedArticles = self.account.fetchArticles(.articleIDs(expectedArticleIds))
			XCTAssertEqual(expectedArticles.count, expectedArticleIds.count, "Did not fetch all the articles.")
			
			let starredArticles = self.account.fetchArticles(.articleIDs(starredArticleIds))
			XCTAssertEqual(expectedArticleIds.count, expectedArticles.count)
			let missingArticles = expectedArticles.subtracting(starredArticles)
			XCTAssertTrue(missingArticles.isEmpty, "These articles should be starred and fetched.")
			XCTAssertEqual(expectedArticles, starredArticles)
			
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
	
	func testIngestsOnePageFailure() {
		let service = TestGetStreamContentsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		
		service.mockResult = .failure(URLError(.timedOut))
		
		let getStreamContentsExpectation = expectation(description: "Did Get Page of Stream Contents")
		getStreamContentsExpectation.expectedFulfillmentCount = 1
		
		service.getStreamContentsExpectation = getStreamContentsExpectation
		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertNil(serviceNewerThan)
			XCTAssertNil(continuation)
			XCTAssertNil(serviceUnreadOnly)
		}
		
		let syncStarred = FeedlySyncStarredArticlesOperation(account: account, resource: resource, service: service, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		syncStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(syncStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { starredArticleIds in
			XCTAssertTrue(starredArticleIds.isEmpty)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
	
	func testIngestsManyPagesSuccess() {
		let service = TestGetPagedStreamContentsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		
		let continuations = (1...10).map { "\($0)" }
		service.addAtLeastOnePage(for: resource, continuations: continuations, numberOfEntriesPerPage: 10)
		
		let getStreamContentsExpectation = expectation(description: "Did Get Page of Stream Contents")
		getStreamContentsExpectation.expectedFulfillmentCount = 1 + continuations.count
		
		var remainingContinuations = Set(continuations)
		let getStreamPageExpectation = expectation(description: "Did Request Page")
		getStreamPageExpectation.expectedFulfillmentCount = 1 + continuations.count
		
		service.getStreamContentsExpectation = getStreamContentsExpectation
		service.parameterTester = { serviceResource, continuation, serviceNewerThan, serviceUnreadOnly in
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertNil(serviceNewerThan)
			XCTAssertNil(serviceUnreadOnly)
			
			if let continuation = continuation {
				XCTAssertTrue(remainingContinuations.contains(continuation))
				remainingContinuations.remove(continuation)
			}
			
			getStreamPageExpectation.fulfill()
		}
		
		let syncStarred = FeedlySyncStarredArticlesOperation(account: account, resource: resource, service: service, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		syncStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(syncStarred)
		
		waitForExpectations(timeout: 2)
		
		// Find articles inserted.
		let expectedArticleIds = Set(service.pages.values.map { $0.items }.flatMap { $0 }.map { $0.id })
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { starredArticleIds in
			let missingIds = expectedArticleIds.subtracting(starredArticleIds)
			XCTAssertTrue(missingIds.isEmpty, "These article ids were not marked as starred.")
			
			// Fetch articles directly because account.fetchArticles(.starred) fetches starred articles for feeds subscribed to.
			let expectedArticles = self.account.fetchArticles(.articleIDs(expectedArticleIds))
			XCTAssertEqual(expectedArticles.count, expectedArticleIds.count, "Did not fetch all the articles.")
			
			let starredArticles = self.account.fetchArticles(.articleIDs(starredArticleIds))
			XCTAssertEqual(expectedArticleIds.count, expectedArticles.count)
			let missingArticles = expectedArticles.subtracting(starredArticles)
			XCTAssertTrue(missingArticles.isEmpty, "These articles should be starred and fetched.")
			XCTAssertEqual(expectedArticles, starredArticles)
			
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
}
