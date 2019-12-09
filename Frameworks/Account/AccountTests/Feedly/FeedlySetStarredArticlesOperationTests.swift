//
//  FeedlySetStarredArticlesOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 25/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSParser

class FeedlySetStarredArticlesOperationTests: XCTestCase {
	
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
	
	struct TestStarredArticleProvider: FeedlyStarredEntryIdProviding {
		var entryIds: Set<String>
	}
	
	func testEmptyArticleIds() {
		let testIds = Set<String>()
		let provider = TestStarredArticleProvider(entryIds: testIds)
		
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertTrue(accountArticlesIDs.isEmpty)
			XCTAssertEqual(accountArticlesIDs, testIds)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSetOneArticleIdStarred() {
		let testIds = Set<String>(["feed/0/article/0"])
		let provider = TestStarredArticleProvider(entryIds: testIds)
		
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertEqual(accountArticlesIDs.count, testIds.count)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSetManyArticleIdsStarred() {
		let testIds = Set<String>((0..<10_000).map { "feed/0/article/\($0)" })
		let provider = TestStarredArticleProvider(entryIds: testIds)
		
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertEqual(accountArticlesIDs.count, testIds.count)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSetSomeArticleIdsUnstarred() {
		let initialStarredIds = Set<String>((0..<1000).map { "feed/0/article/\($0)" })
		
		do {
			let provider = TestStarredArticleProvider(entryIds: initialStarredIds)
			let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish Setting Initial Unreads")
			setStarred.completionBlock = {
				completionExpectation.fulfill()
			}
			
			OperationQueue.main.addOperation(setStarred)
			
			waitForExpectations(timeout: 2)
		}
		
		let remainingStarredIds = Set(initialStarredIds.enumerated().filter { $0.offset % 2 > 0 }.map { $0.element })
		let provider = TestStarredArticleProvider(entryIds: remainingStarredIds)
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { remainingAccountArticlesIDs in
			XCTAssertEqual(remainingAccountArticlesIDs, remainingStarredIds)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
	
	func testSetAllArticleIdsUnstarred() {
		let initialStarredIds = Set<String>((0..<1000).map { "feed/0/article/\($0)" })
		
		do {
			let provider = TestStarredArticleProvider(entryIds: initialStarredIds)
			let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
			
			let completionExpectation = expectation(description: "Did Finish Setting Initial Unreads")
			setStarred.completionBlock = {
				completionExpectation.fulfill()
			}
			
			OperationQueue.main.addOperation(setStarred)
			
			waitForExpectations(timeout: 2)
		}
		
		let remainingStarredIds = Set<String>()
		let provider = TestStarredArticleProvider(entryIds: remainingStarredIds)
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { remainingAccountArticlesIDs in
			XCTAssertEqual(remainingAccountArticlesIDs, remainingStarredIds)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
	
	// MARK: - Updating Article Unread Status
	
	struct TestItemsByFeedProvider: FeedlyParsedItemsByFeedProviding {
		var providerName: String
		var parsedItemsKeyedByFeedId: [String: Set<ParsedItem>]
	}
	
	func testSetAllArticlesStarred() {
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
		let remainingStarredIds = Set(testItems.compactMap { $0.syncServiceID })
		XCTAssertEqual(testItems.count, remainingStarredIds.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let provider = TestStarredArticleProvider(entryIds: remainingStarredIds)
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertEqual(accountArticlesIDs, remainingStarredIds)
			
			let idsOfStarredArticles = Set(self.account
				.fetchArticles(.articleIDs(remainingStarredIds))
				.filter { $0.status.boolStatus(forKey: .starred) == true }
				.map { $0.articleID })
			
			XCTAssertEqual(idsOfStarredArticles, remainingStarredIds)
		}
		waitForExpectations(timeout: 2)
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
		
		let remainingStarredIds = Set(unreadItems.compactMap { $0.syncServiceID })
		XCTAssertEqual(unreadItems.count, remainingStarredIds.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let provider = TestStarredArticleProvider(entryIds: remainingStarredIds)
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertEqual(accountArticlesIDs, remainingStarredIds)
			
			let idsOfStarredArticles = Set(self.account
				.fetchArticles(.articleIDs(remainingStarredIds))
				.filter { $0.status.boolStatus(forKey: .starred) == true }
				.map { $0.articleID })
			
			XCTAssertEqual(idsOfStarredArticles, remainingStarredIds)
		}
		waitForExpectations(timeout: 2)
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
		let remainingStarredIds = Set([testItems.compactMap { $0.syncServiceID }.first!])
		let provider = TestStarredArticleProvider(entryIds: remainingStarredIds)
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertEqual(accountArticlesIDs, remainingStarredIds)
			
			let idsOfStarredArticles = Set(self.account
				.fetchArticles(.articleIDs(remainingStarredIds))
				.filter { $0.status.boolStatus(forKey: .starred) == true }
				.map { $0.articleID })
			
			XCTAssertEqual(idsOfStarredArticles, remainingStarredIds)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
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
		
		let remainingStarredIds = Set<String>()
		let provider = TestStarredArticleProvider(entryIds: remainingStarredIds)
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertEqual(accountArticlesIDs, remainingStarredIds)
			
			let idsOfStarredArticles = Set(self.account
				.fetchArticles(.articleIDs(remainingStarredIds))
				.filter { $0.status.boolStatus(forKey: .starred) == true }
				.map { $0.articleID })
			
			XCTAssertEqual(idsOfStarredArticles, remainingStarredIds)
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
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
		let remainingStarredIds = Set(testItems.compactMap { $0.syncServiceID })
		XCTAssertEqual(testItems.count, remainingStarredIds.count, "Not every item has a value for \(\ParsedItem.syncServiceID).")
		
		let provider = TestStarredArticleProvider(entryIds: remainingStarredIds)
		let setStarred = FeedlySetStarredArticlesOperation(account: account, allStarredEntryIdsProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		setStarred.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(setStarred)
		
		waitForExpectations(timeout: 2)
		
		let fetchIdsExpectation = expectation(description: "Fetch Article Ids")
		account.fetchStarredArticleIDs { accountArticlesIDs in
			XCTAssertEqual(accountArticlesIDs, remainingStarredIds)
			
			let someTestItems = Set(someItemsAndFeeds.flatMap { $0.value })
			let someRemainingStarredIdsOfIngestedArticles = Set(someTestItems.compactMap { $0.syncServiceID })
			let idsOfStarredArticles = Set(self.account
				.fetchArticles(.articleIDs(someRemainingStarredIdsOfIngestedArticles))
				.filter { $0.status.boolStatus(forKey: .starred) == true }
				.map { $0.articleID })
			
			XCTAssertEqual(idsOfStarredArticles, someRemainingStarredIdsOfIngestedArticles)
			
			fetchIdsExpectation.fulfill()
		}
		waitForExpectations(timeout: 2)
	}
}
