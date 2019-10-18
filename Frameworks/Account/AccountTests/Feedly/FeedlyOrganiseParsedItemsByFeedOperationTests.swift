//
//  FeedlyOrganiseParsedItemsByFeedOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 24/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSParser

class FeedlyOrganiseParsedItemsByFeedOperationTests: XCTestCase {
	
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
	
	struct TestParsedItemsProvider: FeedlyParsedItemProviding {
		var resource: FeedlyResourceId
		var parsedEntries: Set<ParsedItem>
	}
	
	func testNoEntries() {
		let entries = support.makeParsedItemTestDataFor(numberOfFeeds: 0, numberOfItemsInFeeds: 0)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let parsedEntries = Set(entries.values.flatMap { $0 })
		let provider = TestParsedItemsProvider(resource: resource, parsedEntries: parsedEntries)
		
		let organise = FeedlyOrganiseParsedItemsByFeedOperation(account: account, parsedItemProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		organise.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(organise)
		
		waitForExpectations(timeout: 2)
		
		let itemsAndFeedIds = organise.parsedItemsKeyedByFeedId
		XCTAssertEqual(itemsAndFeedIds, entries)
		XCTAssertEqual(resource.id, organise.providerName)
	}
	
	func testGroupsOneEntryByFeedId() {
		let entries = support.makeParsedItemTestDataFor(numberOfFeeds: 1, numberOfItemsInFeeds: 1)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let parsedEntries = Set(entries.values.flatMap { $0 })
		let provider = TestParsedItemsProvider(resource: resource, parsedEntries: parsedEntries)
		
		let organise = FeedlyOrganiseParsedItemsByFeedOperation(account: account, parsedItemProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		organise.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(organise)
		
		waitForExpectations(timeout: 2)
		
		let itemsAndFeedIds = organise.parsedItemsKeyedByFeedId
		XCTAssertEqual(itemsAndFeedIds, entries)
		XCTAssertEqual(resource.id, organise.providerName)
	}
	
	func testGroupsManyEntriesByFeedId() {
		let entries = support.makeParsedItemTestDataFor(numberOfFeeds: 100, numberOfItemsInFeeds: 100)
		let resource = FeedlyCategoryResourceId(id: "user/12345/category/6789")
		let parsedEntries = Set(entries.values.flatMap { $0 })
		let provider = TestParsedItemsProvider(resource: resource, parsedEntries: parsedEntries)
		
		let organise = FeedlyOrganiseParsedItemsByFeedOperation(account: account, parsedItemProvider: provider, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		organise.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(organise)
		
		waitForExpectations(timeout: 2)
		
		let itemsAndFeedIds = organise.parsedItemsKeyedByFeedId
		XCTAssertEqual(itemsAndFeedIds, entries)
		XCTAssertEqual(resource.id, organise.providerName)
	}
}
