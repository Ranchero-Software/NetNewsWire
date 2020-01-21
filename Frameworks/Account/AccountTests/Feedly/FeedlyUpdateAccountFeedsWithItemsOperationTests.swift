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
import RSCore

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
		var parsedItemsByFeedProviderName: String
		var parsedItemsKeyedByFeedId: [String: Set<ParsedItem>]
	}
	
	func testUpdateAccountWithEmptyItems() throws {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 0, numberOfItemsInFeeds: 0)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(parsedItemsByFeedProviderName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = { _ in
			completionExpectation.fulfill()
		}
				
		MainThreadOperationQueue.shared.addOperation(update)
		
		waitForExpectations(timeout: 2)
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = try account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.isEmpty)
	}
	
	func testUpdateAccountWithOneItem() throws {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 1, numberOfItemsInFeeds: 1)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(parsedItemsByFeedProviderName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(update)
		
		waitForExpectations(timeout: 2)
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = try account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.count == entries.count)
		
		let accountArticleIds = Set(accountArticles.map { $0.articleID })
		let missingIds = articleIds.subtracting(accountArticleIds)
		XCTAssertTrue(missingIds.isEmpty)
	}
	
	func testUpdateAccountWithManyItems() throws {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 100, numberOfItemsInFeeds: 100)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(parsedItemsByFeedProviderName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(update)
		
		waitForExpectations(timeout: 10) // 10,000 articles takes ~ three seconds for me.
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = try account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.count == entries.count)
		
		let accountArticleIds = Set(accountArticles.map { $0.articleID })
		let missingIds = articleIds.subtracting(accountArticleIds)
		XCTAssertTrue(missingIds.isEmpty)
	}
	
	func testCancelUpdateAccount() throws {
		let testItems = support.makeParsedItemTestDataFor(numberOfFeeds: 1, numberOfItemsInFeeds: 1)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let provider = TestItemsByFeedProvider(parsedItemsByFeedProviderName: resource.id, parsedItemsKeyedByFeedId: testItems)
		
		let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		update.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(update)
		
		MainThreadOperationQueue.shared.cancelOperations([update])
		
		waitForExpectations(timeout: 2)
		
		let entries = testItems.flatMap { $0.value }
		let articleIds = Set(entries.compactMap { $0.syncServiceID })
		XCTAssertEqual(articleIds.count, entries.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let accountArticles = try account.fetchArticles(.articleIDs(articleIds))
		XCTAssertTrue(accountArticles.isEmpty)
	}
}
