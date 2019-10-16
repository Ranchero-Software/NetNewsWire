//
//  AccountFeedlySyncTest.swift
//  AccountTests
//
//  Created by Kiel Gillard on 30/9/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import Articles

class AccountFeedlySyncTest: XCTestCase {
	
	private let testTransport = TestTransport()
	private var account: Account!
	
	override func setUp() {
		super.setUp()
		
		account = TestAccountManager.shared.createAccount(type: .feedly, transport: testTransport)
		
		do {
			let username = UUID().uuidString
			let credentials = Credentials(type: .oauthAccessToken, username: username, secret: "test")
			try account.storeCredentials(credentials)
		} catch {
			XCTFail("Unable to register mock credentials because \(error)")
		}
	}
	
	override func tearDown() {
		// Clean up
		do {
			try account.removeCredentials(type: .oauthAccessToken)
		} catch {
			XCTFail("Unable to clean up mock credentials because \(error)")
		}
		
		TestAccountManager.shared.deleteAccount(account)
		
		super.tearDown()
	}
	
	// MARK: Initial Sync
	
	func testInitialSync() {
		XCTAssertTrue(account.idToFeedDictionary.isEmpty, "Expected to be testing a fresh account without any existing feeds.")
		XCTAssertTrue((account.folders ?? Set()).isEmpty, "Expected to be testing a fresh account without any existing folders.")
		
		set(testFiles: .initial, with: testTransport)
		
		// Test initial folders for collections and feeds for collection feeds.
		let initialExpection = self.expectation(description: "Initial feeds")
		account.refreshAll() { _ in
			initialExpection.fulfill()
		}
		waitForExpectations(timeout: 5)
		
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_initial")
		checkArticles(againstItemsInStreamInJSONNamed: "macintosh_initial")
		checkArticles(againstItemsInStreamInJSONNamed: "mustread_initial")
		checkArticles(againstItemsInStreamInJSONNamed: "programming_initial")
		checkArticles(againstItemsInStreamInJSONNamed: "uncategorized_initial")
		checkArticles(againstItemsInStreamInJSONNamed: "weblogs_initial")
	}
	
	// MARK: Add Collection
	
	func testAddsFoldersForCollections() {
		prepareBaseline(.initial)
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_initial")
		
		set(testFiles: .addCollection, with: testTransport)
		
		let addCollectionExpectation = self.expectation(description: "Adds NewCollection")
		account.refreshAll() { _ in
			addCollectionExpectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_addcollection")
		checkArticles(againstItemsInStreamInJSONNamed: "newcollection_addcollection")
	}
	
	// MARK: Add Feed
	
	func testAddsFeeds() {
		prepareBaseline(.addCollection)
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_addcollection")
		checkArticles(againstItemsInStreamInJSONNamed: "mustread_initial")
		
		set(testFiles: .addFeed, with: testTransport)
		
		let addFeedExpectation = self.expectation(description: "Add Feed To Must Read (hey, that rhymes!)")
		account.refreshAll() { _ in
			addFeedExpectation.fulfill()
		}
		waitForExpectations(timeout: 5)

		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_addfeed")
		checkArticles(againstItemsInStreamInJSONNamed: "mustread_addfeed")
	}
	
	// MARK: Remove Feed
	
	func testRemovesFeeds() {
		prepareBaseline(.addFeed)
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_addfeed")
		checkArticles(againstItemsInStreamInJSONNamed: "mustread_addfeed")
		
		set(testFiles: .removeFeed, with: testTransport)
		
		let removeFeedExpectation = self.expectation(description: "Remove Feed from Must Read")
		account.refreshAll() { _ in
			removeFeedExpectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_addcollection")
		checkArticles(againstItemsInStreamInJSONNamed: "mustread_initial")
	}
	
	func testRemoveCollection() {
		prepareBaseline(.addFeed)
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_addfeed")
		
		set(testFiles: .removeCollection, with: testTransport)
		
		let removeCollectionExpectation = self.expectation(description: "Remove Collection")
		account.refreshAll() { _ in
			removeCollectionExpectation.fulfill()
		}
		waitForExpectations(timeout: 5)
		
		checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed: "feedly_collections_initial")
	}
	
	// MARK: Utility
	
	func prepareBaseline(_ testFiles: TestFiles) {
		XCTAssertTrue(account.idToFeedDictionary.isEmpty, "Expected to be testing a fresh accout.")
		
		set(testFiles: testFiles, with: testTransport)
		
		// Test initial folders for collections and feeds for collection feeds.
		let preparationExpectation = self.expectation(description: "Prepare Account")
		account.refreshAll() { _ in
			preparationExpectation.fulfill()
		}
		// If there's a failure here, then an operation hasn't completed.
		// Check that test files have responses for all the requests this might make.
		waitForExpectations(timeout: 5)
	}
	
	func checkFoldersAndFeeds(againstCollectionsAndFeedsInJSONNamed name: String) {
		let collections = testJSON(named: name) as! [[String:Any]]
		let collectionNames = Set(collections.map { $0["label"] as! String })
		let collectionIds = Set(collections.map { $0["id"] as! String })
		
		let folders = account.folders ?? Set()
		let folderNames = Set(folders.compactMap { $0.name })
		let folderIds = Set(folders.compactMap { $0.externalID })
		
		let missingNames = collectionNames.subtracting(folderNames)
		let missingIds = collectionIds.subtracting(folderIds)
		
		XCTAssertEqual(folders.count, collections.count, "Mismatch between collections and folders.")
		XCTAssertTrue(missingNames.isEmpty, "Collections with these names did not have a corresponding folder with the same name.")
		XCTAssertTrue(missingIds.isEmpty, "Collections with these ids did not have a corresponding folder with the same id.")
		
		for collection in collections {
			checkSingleFolderAndFeeds(againstOneCollectionAndFeedsInJSONPayload: collection)
		}
	}
	
	func checkSingleFolderAndFeeds(againstOneCollectionAndFeedsInJSONNamed name: String) {
		let collection = testJSON(named: name) as! [String:Any]
		checkSingleFolderAndFeeds(againstOneCollectionAndFeedsInJSONPayload: collection)
	}
	
	func checkSingleFolderAndFeeds(againstOneCollectionAndFeedsInJSONPayload collection: [String: Any]) {
		let label = collection["label"] as! String
		guard let folder = account.existingFolder(with: label) else {
			// due to a previous test failure?
			XCTFail("Could not find the \"\(label)\" folder.")
			return
		}
		let collectionFeeds = collection["feeds"] as! [[String: Any]]
		let folderFeeds = folder.topLevelFeeds
		
		XCTAssertEqual(collectionFeeds.count, folderFeeds.count)
		
		let collectionFeedIds = Set(collectionFeeds.map { $0["id"] as! String })
		let folderFeedIds = Set(folderFeeds.map { $0.feedID })
		let missingFeedIds = collectionFeedIds.subtracting(folderFeedIds)
		
		XCTAssertTrue(missingFeedIds.isEmpty, "Feeds with these ids were not found in the \"\(label)\" folder.")
	}
	
	func checkArticles(againstItemsInStreamInJSONNamed name: String) {
		let stream = testJSON(named: name) as! [String:Any]
		checkArticles(againstItemsInStreamInJSONPayload: stream)
	}
	
	func checkArticles(againstItemsInStreamInJSONPayload stream: [String: Any]) {
		
		struct ArticleItem {
			var id: String
			var feedId: String
			var content: String
			var JSON: [String: Any]
			var unread: Bool
			
			/// Convoluted external URL logic "documented" here:
			/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
			var externalUrl: String? {
				return ((JSON["canonical"] as? [[String: Any]]) ?? (JSON["alternate"] as? [[String: Any]]))?.compactMap { link -> String? in
					let href = link["href"] as? String
					if let type = link["type"] as? String {
						if type == "text/html" {
							return href
						}
						return nil
					}
					return href
				}.first
			}
			
			init(item: [String: Any]) {
				self.JSON = item
				self.id = item["id"] as! String
				
				let origin = item["origin"] as! [String: Any]
				self.feedId = origin["streamId"] as! String
				
				let content = item["content"] as? [String: Any]
				let summary = item["summary"] as? [String: Any]
				self.content = ((content ?? summary)?["content"] as? String) ?? ""
				
				self.unread = item["unread"] as! Bool
			}
		}
		
		let items = stream["items"] as! [[String: Any]]
		let articleItems = items.map { ArticleItem(item: $0) }
		let itemIds = Set(articleItems.map { $0.id })
		
		let articles = account.fetchArticles(.articleIDs(itemIds))
		let articleIds = Set(articles.map { $0.articleID })
		
		let missing = itemIds.subtracting(articleIds)
		
		XCTAssertEqual(items.count, articles.count)
		XCTAssertTrue(missing.isEmpty, "Items with these ids did not have a corresponding article with the same id.")
		
		for article in articles {
			for item in articleItems where item.id == article.articleID {
				
				XCTAssertEqual(article.uniqueID, item.id)
				XCTAssertEqual(article.contentHTML, item.content)
				XCTAssertEqual(article.feedID, item.feedId)
				XCTAssertEqual(article.externalURL, item.externalUrl)
				// XCTAssertEqual(article.status.boolStatus(forKey: .read), item.unread)
			}
		}
	}
	
	func testJSON(named: String) -> Any {
		let bundle = Bundle(for: TestTransport.self)
		let url = bundle.url(forResource: named, withExtension: "json")!
		let data = try! Data(contentsOf: url)
		let json = try! JSONSerialization.jsonObject(with: data)
		return json
	}
	
	enum TestFiles {
		case initial
		case addCollection
		case addFeed
		case removeFeed
		case removeCollection
	}
	
	func set(testFiles: TestFiles, with transport: TestTransport) {
		// TestTransport blacklists certain query items to make mocking responses easier.
		let collectionsEndpoint = "/v3/collections"
		switch testFiles {
		case .initial:
			let dict = [
				"/global.saved": "saved_initial.json",
				collectionsEndpoint: "feedly_collections_initial.json",
				"/5ca4d61d-e55d-4999-a8d1-c3b9d8789815": "macintosh_initial.json",
				"/global.must": "mustread_initial.json",
				"/885f2e01-d314-4e63-abac-17dcb063f5b5": "programming_initial.json",
				"/66132046-6f14-488d-b590-8e93422723c8": "uncategorized_initial.json",
				"/e31b3fcb-27f6-4f3e-b96c-53902586e366": "weblogs_initial.json",
			]
			transport.testFiles = dict
			
		case .addCollection:
			set(testFiles: .initial, with: transport)
			
			var dict = transport.testFiles
			dict[collectionsEndpoint] = "feedly_collections_addcollection.json"
			dict["/fc09f383-5a9a-4daa-a575-3efc1733b173"] = "newcollection_addcollection.json"
			transport.testFiles = dict
			
		case .addFeed:
			set(testFiles: .addCollection, with: transport)
			
			var dict = transport.testFiles
			dict[collectionsEndpoint] = "feedly_collections_addfeed.json"
			dict["/global.must"] = "mustread_addfeed.json"
			transport.testFiles = dict
			
		case .removeFeed:
			set(testFiles: .addCollection, with: transport)
			
		case .removeCollection:
			set(testFiles: .initial, with: transport)
		}
	}
}
