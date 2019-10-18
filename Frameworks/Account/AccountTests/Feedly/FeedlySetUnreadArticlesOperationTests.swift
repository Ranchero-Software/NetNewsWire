//
//  FeedlySetUnreadArticlesOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 24/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSParser

class FeedlySetUnreadArticlesOperationTests: XCTestCase {
	
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
	
	// MARK: - Ensuring Unread Status By Id
	
	struct TestUnreadArticleIdProvider: FeedlyUnreadEntryIdProviding {
		var entryIds: Set<String>
	}
	
	func testEmptyArticleIds() {
		let testIds = Set<String>()
		let provider = TestUnreadArticleIdProvider(entryIds: testIds)
		
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertTrue(accountArticlesIDs.isEmpty)
		XCTAssertEqual(accountArticlesIDs.count, testIds.count)
	}
	
	func testSetOneArticleIdUnread() {
		let testIds = Set<String>(["feed/0/article/0"])
		let provider = TestUnreadArticleIdProvider(entryIds: testIds)
		
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(accountArticlesIDs.count, testIds.count)
	}
	
	func testSetManyArticleIdsUnread() {
		let testIds = Set<String>((0..<10_000).map { "feed/0/article/\($0)" })
		let provider = TestUnreadArticleIdProvider(entryIds: testIds)
		
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(accountArticlesIDs.count, testIds.count)
	}
	
	func testSetSomeArticleIdsRead() {
		let initialUnreadIds = Set<String>((0..<1000).map { "feed/0/article/\($0)" })
		
		do {
			let provider = TestUnreadArticleIdProvider(entryIds: initialUnreadIds)
			let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish Setting Initial Unreads")
			setUnread.completionBlock = {
				completionExpectation.fulfill()
			}
			
			OperationQueue.main.addOperation(setUnread)
			
			waitForExpectations(timeout: 2)
		}
		
		let remainingUnreadIds = Set(initialUnreadIds.enumerated().filter { $0.offset % 2 > 0 }.map { $0.element })
		let provider = TestUnreadArticleIdProvider(entryIds: remainingUnreadIds)
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let remainingAccountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(remainingAccountArticlesIDs, remainingUnreadIds)
	}
	
	func testSetAllArticleIdsRead() {
		let initialUnreadIds = Set<String>((0..<1000).map { "feed/0/article/\($0)" })
		
		do {
			let provider = TestUnreadArticleIdProvider(entryIds: initialUnreadIds)
			let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish Setting Initial Unreads")
			setUnread.completionBlock = {
				completionExpectation.fulfill()
			}
			
			OperationQueue.main.addOperation(setUnread)
			
			waitForExpectations(timeout: 2)
		}
		
		let remainingUnreadIds = Set<String>()
		let provider = TestUnreadArticleIdProvider(entryIds: remainingUnreadIds)
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let remainingAccountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(remainingAccountArticlesIDs, remainingUnreadIds)
	}
	
	// MARK: - Updating Article Unread Status
	
	struct TestItemsByFeedProvider: FeedlyParsedItemsByFeedProviding {
		var providerName: String
		var parsedItemsKeyedByFeedId: [String: Set<ParsedItem>]
	}
	
	func testSetAllArticlesUnread() {
		let testItemsAndFeeds = support.makeParsedItemTestDataFor(numberOfFeeds: 5, numberOfItemsInFeeds: 100)
		
		do {
			let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
			let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItemsAndFeeds)
			let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish")
			update.completionBlock = {
				completionExpectation.fulfill()
			}
					
			OperationQueue.main.addOperation(update)
			
			waitForExpectations(timeout: 2)
		}
		
		let testItems = Set(testItemsAndFeeds.flatMap { $0.value })
		let remainingUnreadIds = Set(testItems.compactMap { $0.syncServiceID })
		XCTAssertEqual(testItems.count, remainingUnreadIds.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let provider = TestUnreadArticleIdProvider(entryIds: remainingUnreadIds)
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(accountArticlesIDs, remainingUnreadIds)
		
		let idsOfUnreadArticles = Set(account
			.fetchArticles(.articleIDs(remainingUnreadIds))
			.filter { $0.status.boolStatus(forKey: .read) == false }
			.map { $0.articleID })
		
		XCTAssertEqual(idsOfUnreadArticles, remainingUnreadIds)
	}
	
	func testSetManyArticlesUnread() {
		let testItemsAndFeeds = support.makeParsedItemTestDataFor(numberOfFeeds: 5, numberOfItemsInFeeds: 100)
		
		do {
			let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
			let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItemsAndFeeds)
			let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish")
			update.completionBlock = {
				completionExpectation.fulfill()
			}
					
			OperationQueue.main.addOperation(update)
			
			waitForExpectations(timeout: 2)
		}
		
		let testItems = Set(testItemsAndFeeds.flatMap { $0.value })
		let unreadItems = testItems
			.enumerated()
			.filter { $0.offset % 2 > 0 }
			.map { $0.element }
		
		let remainingUnreadIds = Set(unreadItems.compactMap { $0.syncServiceID })
		XCTAssertEqual(unreadItems.count, remainingUnreadIds.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let provider = TestUnreadArticleIdProvider(entryIds: remainingUnreadIds)
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(accountArticlesIDs, remainingUnreadIds)
		
		let idsOfUnreadArticles = Set(account
			.fetchArticles(.articleIDs(remainingUnreadIds))
			.filter { $0.status.boolStatus(forKey: .read) == false }
			.map { $0.articleID })
		
		XCTAssertEqual(idsOfUnreadArticles, remainingUnreadIds)
	}
	
	func testSetOneArticleUnread() {
		let testItemsAndFeeds = support.makeParsedItemTestDataFor(numberOfFeeds: 5, numberOfItemsInFeeds: 100)
		
		do {
			let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
			let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItemsAndFeeds)
			let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish")
			update.completionBlock = {
				completionExpectation.fulfill()
			}
					
			OperationQueue.main.addOperation(update)
			
			waitForExpectations(timeout: 2)
		}
		
		let testItems = Set(testItemsAndFeeds.flatMap { $0.value })
		// Since the test data is completely under the developer's control, not having at least one can be a programmer error.
		let remainingUnreadIds = Set([testItems.compactMap { $0.syncServiceID }.first!])
		let provider = TestUnreadArticleIdProvider(entryIds: remainingUnreadIds)
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(accountArticlesIDs, remainingUnreadIds)
		
		let idsOfUnreadArticles = Set(account
			.fetchArticles(.articleIDs(remainingUnreadIds))
			.filter { $0.status.boolStatus(forKey: .read) == false }
			.map { $0.articleID })
		
		XCTAssertEqual(idsOfUnreadArticles, remainingUnreadIds)
	}
	
	func testSetNoArticlesRead() {
		let testItemsAndFeeds = support.makeParsedItemTestDataFor(numberOfFeeds: 5, numberOfItemsInFeeds: 100)
		
		do {
			let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
			let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: testItemsAndFeeds)
			
			let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish")
			update.completionBlock = {
				completionExpectation.fulfill()
			}
					
			OperationQueue.main.addOperation(update)
			
			waitForExpectations(timeout: 2)
		}
		
		let remainingUnreadIds = Set<String>()
		let provider = TestUnreadArticleIdProvider(entryIds: remainingUnreadIds)
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(accountArticlesIDs, remainingUnreadIds)
		
		let idsOfUnreadArticles = Set(account
			.fetchArticles(.articleIDs(remainingUnreadIds))
			.filter { $0.status.boolStatus(forKey: .read) == false }
			.map { $0.articleID })
		
		XCTAssertEqual(idsOfUnreadArticles, remainingUnreadIds)
	}
	
	func testSetAllArticlesAndArticleIdsWithSomeArticlesIngested() {
		let testItemsAndFeeds = support.makeParsedItemTestDataFor(numberOfFeeds: 5, numberOfItemsInFeeds: 100)
		let someItemsAndFeeds = Dictionary(uniqueKeysWithValues: testItemsAndFeeds.enumerated().filter { $0.offset % 2 > 0 }.map { $0.element })
		
		do {
			let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
			let provider = TestItemsByFeedProvider(providerName: resource.id, parsedItemsKeyedByFeedId: someItemsAndFeeds)
			let update = FeedlyUpdateAccountFeedsWithItemsOperation(account: account, organisedItemsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish")
			update.completionBlock = {
				completionExpectation.fulfill()
			}
					
			OperationQueue.main.addOperation(update)
			
			waitForExpectations(timeout: 2)
		}
		
		let testItems = Set(testItemsAndFeeds.flatMap { $0.value })
		let remainingUnreadIds = Set(testItems.compactMap { $0.syncServiceID })
		XCTAssertEqual(testItems.count, remainingUnreadIds.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let provider = TestUnreadArticleIdProvider(entryIds: remainingUnreadIds)
		let setUnread = FeedlySetUnreadArticlesOperation(account: account, allUnreadIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setUnread.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setUnread)
		
		waitForExpectations(timeout: 2)
		
		let accountArticlesIDs = account.fetchUnreadArticleIDs()
		XCTAssertEqual(accountArticlesIDs, remainingUnreadIds)
		
		let someTestItems = Set(someItemsAndFeeds.flatMap { $0.value })
		let someRemainingUnreadIdsOfIngestedArticles = Set(someTestItems.compactMap { $0.syncServiceID })
		let idsOfUnreadArticles = Set(account
			.fetchArticles(.articleIDs(someRemainingUnreadIdsOfIngestedArticles))
			.filter { $0.status.boolStatus(forKey: .read) == false }
			.map { $0.articleID })
		
		XCTAssertEqual(idsOfUnreadArticles, someRemainingUnreadIdsOfIngestedArticles)
	}
}
