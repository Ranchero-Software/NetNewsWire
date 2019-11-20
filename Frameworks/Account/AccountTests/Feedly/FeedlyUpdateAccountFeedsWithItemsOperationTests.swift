//
//  FeedlyUpdateAccountFeedsWithItemsOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 24/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSParser

class FeedlyUpdateAccountFeedsWithItemsOperationTests: XCTestCase {
	
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
	
	struct TestItemsByFeedProvider: FeedlyParsedItemsByFeedProviding {
		var providerName: String
		var parsedItemsKeyedByFeedId: [String: Set<ParsedItem>]
	}
	
	func testUpdateAccountWithEmptyItems() {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 0, numberOfItemsInFeeds: 0)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = {
			completionExpectation.fulfill()
		}
				
		OperationQueue.main.addOperation(update)
		
		waitForExpectations(timeout: 2)
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.isEmpty)
	}
	
	func testUpdateAccountWithOneItem() {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 1, numberOfItemsInFeeds: 1)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(update)
		
		waitForExpectations(timeout: 2)
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.count == entries.count)
		
		let accountArticleIds = Set(accountArticles.map { $0.articleID })
		let missingIds = articleIds.subtracting(accountArticleIds)
		XCTAssertTrue(missingIds.isEmpty)
	}
	
	func testUpdateAccountWithManyItems() {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 100, numberOfItemsInFeeds: 100)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(update)
		
		waitForExpectations(timeout: 10) // 10,000 articles takes ~ three seconds for me.
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.count == entries.count)
		
		let accountArticleIds = Set(accountArticles.map { $0.articleID })
		let missingIds = articleIds.subtracting(accountArticleIds)
		XCTAssertTrue(missingIds.isEmpty)
	}
	
	func testCancelUpdateAccount() {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 1, numberOfItemsInFeeds: 1)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(update)
		
		update.cancel()
		
		waitForExpectations(timeout: 2)
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.isEmpty)
	}
}
