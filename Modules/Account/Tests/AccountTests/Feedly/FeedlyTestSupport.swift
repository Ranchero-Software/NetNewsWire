//
//  FeedlyTestSupport.swift
//  AccountTests
//
//  Created by Kiel Gillard on 22/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
import Parser
import Secrets
@testable import Account
import os.log
import SyncDatabase

//class FeedlyTestSupport {
//	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "FeedlyTests")
//	var accessToken = Credentials(type: .oauthAccessToken, username: "Test", secret: "t3st-access-tok3n")
//	var refreshToken = Credentials(type: .oauthRefreshToken, username: "Test", secret: "t3st-refresh-tok3n")
//	var transport = TestTransport()
//	
//	func makeMockNetworkStack() -> (TestTransport, FeedlyAPICaller) {
//		let caller = FeedlyAPICaller(transport: transport, api: .sandbox)
//		caller.credentials = accessToken
//		return (transport, caller)
//	}
//	
//	func makeTestAccount() -> Account {
//		let manager = TestAccountManager()
//		let account = manager.createAccount(type: .feedly, transport: transport)
//		do {
//			try account.storeCredentials(refreshToken)
//			// This must be done last or the account uses the refresh token for request Authorization!
//			try account.storeCredentials(accessToken)
//		} catch {
//			XCTFail("Unable to register mock credentials because \(error)")
//		}
//		return account
//	}
//	
//	func makeMockOAuthClient() -> OAuthAuthorizationClient {
//		return OAuthAuthorizationClient(id: "test", redirectURI: "test://test/auth", state: nil, secret: "password")
//	}
//	
//	func removeCredentials(matching type: CredentialsType, from account: Account) {
//		do {
//			try account.removeCredentials(type: type)
//		} catch {
//			XCTFail("Unable to remove \(type)")
//		}
//	}
//	
//	func makeTestDatabaseContainer() -> TestDatabaseContainer {
//		return TestDatabaseContainer()
//	}
//	
//	class TestDatabaseContainer {
//		private let path: String
//		private(set) var database: SyncDatabase!
//		
//		init() {
//			let dataFolder = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//			path = dataFolder.appendingPathComponent("\(UUID().uuidString)-Sync.sqlite3").path
//			database = SyncDatabase(databasePath: path)
//		}
//		
//		deinit {
//			// We should close the database before removing the database.
//			database = nil
//			do {
//				try FileManager.default.removeItem(atPath: path)
//				print("Removed database at \(path)")
//			} catch {
//				print("Unable to remove database owned by \(self) because \(error).")
//			}
//		}
//	}
//	
//	func destroy(_ testAccount: Account) {
//		do {
//			// These should not throw when the keychain items are not found.
//			try testAccount.removeCredentials(type: .oauthAccessToken)
//			try testAccount.removeCredentials(type: .oauthRefreshToken)
//		} catch {
//			XCTFail("Unable to clean up mock credentials because \(error)")
//		}
//		
//		let manager = TestAccountManager()
//		manager.deleteAccount(testAccount)
//	}
//	
//	func testJSON(named: String, subdirectory: String? = nil) -> Any {
//		let url = Bundle.module.url(forResource: named, withExtension: "json", subdirectory: subdirectory)!
//		let data = try! Data(contentsOf: url)
//		let json = try! JSONSerialization.jsonObject(with: data)
//		return json
//	}
//	
//	func checkFoldersAndFeeds(in account: Account, againstCollectionsAndFeedsInJSONNamed name: String, subdirectory: String? = nil) {
//		let collections = testJSON(named: name, subdirectory: subdirectory) as! [[String:Any]]
//		let collectionNames = Set(collections.map { $0["label"] as! String })
//		let collectionIDs = Set(collections.map { $0["id"] as! String })
//		
//		let folders = account.folders ?? Set()
//		let folderNames = Set(folders.compactMap { $0.name })
//		let folderIDs = Set(folders.compactMap { $0.externalID })
//		
//		let missingNames = collectionNames.subtracting(folderNames)
//		let missingIDs = collectionIDs.subtracting(folderIDs)
//		
//		XCTAssertEqual(folders.count, collections.count, "Mismatch between collections and folders.")
//		XCTAssertTrue(missingNames.isEmpty, "Collections with these names did not have a corresponding folder with the same name.")
//		XCTAssertTrue(missingIDs.isEmpty, "Collections with these ids did not have a corresponding folder with the same id.")
//		
//		for collection in collections {
//			checkSingleFolderAndFeeds(in: account, againstOneCollectionAndFeedsInJSONPayload: collection)
//		}
//	}
//	
//	func checkSingleFolderAndFeeds(in account: Account, againstOneCollectionAndFeedsInJSONNamed name: String) {
//		let collection = testJSON(named: name) as! [String:Any]
//		checkSingleFolderAndFeeds(in: account, againstOneCollectionAndFeedsInJSONPayload: collection)
//	}
//	
//	func checkSingleFolderAndFeeds(in account: Account, againstOneCollectionAndFeedsInJSONPayload collection: [String: Any]) {
//		let label = collection["label"] as! String
//		guard let folder = account.existingFolder(with: label) else {
//			// due to a previous test failure?
//			XCTFail("Could not find the \"\(label)\" folder.")
//			return
//		}
//		let collectionFeeds = collection["feeds"] as! [[String: Any]]
//		let folderFeeds = folder.topLevelFeeds
//		
//		XCTAssertEqual(collectionFeeds.count, folderFeeds.count)
//		
//		let collectionFeedIDs = Set(collectionFeeds.map { $0["id"] as! String })
//		let folderFeedIDs = Set(folderFeeds.map { $0.feedID })
//		let missingFeedIDs = collectionFeedIDs.subtracting(folderFeedIDs)
//		
//		XCTAssertTrue(missingFeedIDs.isEmpty, "Feeds with these ids were not found in the \"\(label)\" folder.")
//	}
//	
//	func checkArticles(in account: Account, againstItemsInStreamInJSONNamed name: String, subdirectory: String? = nil) throws {
//		let stream = testJSON(named: name, subdirectory: subdirectory) as! [String:Any]
//		try checkArticles(in: account, againstItemsInStreamInJSONPayload: stream)
//	}
//	
//	func checkArticles(in account: Account, againstItemsInStreamInJSONPayload stream: [String: Any]) throws {
//		try checkArticles(in: account, correspondToStreamItemsIn: stream)
//	}
//	
//	private struct ArticleItem {
//		var id: String
//		var feedID: String
//		var content: String
//		var JSON: [String: Any]
//		var unread: Bool
//		
//		/// Convoluted external URL logic "documented" here:
//		/// https://groups.google.com/forum/#!searchin/feedly-cloud/feed$20url%7Csort:date/feedly-cloud/Rx3dVd4aTFQ/Hf1ZfLJoCQAJ
//		var externalUrl: String? {
//			return ((JSON["canonical"] as? [[String: Any]]) ?? (JSON["alternate"] as? [[String: Any]]))?.compactMap { link -> String? in
//				let href = link["href"] as? String
//				if let type = link["type"] as? String {
//					if type == "text/html" {
//						return href
//					}
//					return nil
//				}
//				return href
//			}.first
//		}
//		
//		init(item: [String: Any]) {
//			self.JSON = item
//			self.id = item["id"] as! String
//			
//			let origin = item["origin"] as! [String: Any]
//			self.feedID = origin["streamId"] as! String
//			
//			let content = item["content"] as? [String: Any]
//			let summary = item["summary"] as? [String: Any]
//			self.content = ((content ?? summary)?["content"] as? String) ?? ""
//			
//			self.unread = item["unread"] as! Bool
//		}
//	}
//	
//	/// Awkwardly titled to make it clear the JSON given is from a stream response.
//	func checkArticles(in testAccount: Account, correspondToStreamItemsIn stream: [String: Any]) throws {
//
//		let items = stream["items"] as! [[String: Any]]
//		let articleItems = items.map { ArticleItem(item: $0) }
//		let itemIDs = Set(articleItems.map { $0.id })
//		
//		let articles = try testAccount.fetchArticles(.articleIDs(itemIDs))
//		let articleIDs = Set(articles.map { $0.articleID })
//		
//		let missing = itemIDs.subtracting(articleIDs)
//		
//		XCTAssertEqual(items.count, articles.count)
//		XCTAssertTrue(missing.isEmpty, "Items with these ids did not have a corresponding article with the same id.")
//		
//		for article in articles {
//			for item in articleItems where item.id == article.articleID {
//				XCTAssertEqual(article.uniqueID, item.id)
//				XCTAssertEqual(article.contentHTML, item.content)
//				XCTAssertEqual(article.feedID, item.feedId)
//				XCTAssertEqual(article.externalURL, item.externalUrl)
//			}
//		}
//	}
//	
//	func checkUnreadStatuses(in account: Account, againstIDsInStreamInJSONNamed name: String, subdirectory: String? = nil, testCase: XCTestCase) {
//		let streadIDs = testJSON(named: name, subdirectory: subdirectory) as! [String:Any]
//		checkUnreadStatuses(in: account, correspondToIDsInJSONPayload: streadIDs, testCase: testCase)
//	}
//	
//	func checkUnreadStatuses(in testAccount: Account, correspondToIDsInJSONPayload streadIDs: [String: Any], testCase: XCTestCase) {
//		let ids = Set(streadIDs["ids"] as! [String])
//		let fetchIDsExpectation = testCase.expectation(description: "Fetch Article IDs")
//		testAccount.fetchUnreadArticleIDs { articleIDsResult in
//			do {
//				let articleIDs = try articleIDsResult.get()
//				// Unread statuses can be paged from Feedly.
//				// Instead of joining test data, the best we can do is
//				// make sure that these ids are marked as unread (a subset of the total).
//				XCTAssertTrue(ids.isSubset(of: articleIDs), "Some articles in `ids` are not marked as unread.")
//				fetchIDsExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping article IDs: \(error)")
//			}
//		}
//		testCase.wait(for: [fetchIDsExpectation], timeout: 2)
//	}
//	
//	func checkStarredStatuses(in account: Account, againstItemsInStreamInJSONNamed name: String, subdirectory: String? = nil, testCase: XCTestCase) {
//		let streadIDs = testJSON(named: name, subdirectory: subdirectory) as! [String:Any]
//		checkStarredStatuses(in: account, correspondToStreamItemsIn: streadIDs, testCase: testCase)
//	}
//	
//	func checkStarredStatuses(in testAccount: Account, correspondToStreamItemsIn stream: [String: Any], testCase: XCTestCase) {
//		let items = stream["items"] as! [[String: Any]]
//		let ids = Set(items.map { $0["id"] as! String })
//		let fetchIDsExpectation = testCase.expectation(description: "Fetch Article Ids")
//		testAccount.fetchStarredArticleIDs { articleIDsResult in
//			do {
//				let articleIDs = try articleIDsResult.get()
//				// Starred articles can be paged from Feedly.
//				// Instead of joining test data, the best we can do is
//				// make sure that these articles are marked as starred (a subset of the total).
//				XCTAssertTrue(ids.isSubset(of: articleIDs), "Some articles in `ids` are not marked as starred.")
//				fetchIDsExpectation.fulfill()
//			} catch {
//				XCTFail("Error unwrapping article IDs: \(error)")
//			}
//		}
//		testCase.wait(for: [fetchIDsExpectation], timeout: 2)
//	}
//	
//	func check(_ entries: [FeedlyEntry], correspondToStreamItemsIn stream: [String: Any]) {
//		
//		let items = stream["items"] as! [[String: Any]]
//		let itemIDs = Set(items.map { $0["id"] as! String })
//		
//		let articleIDs = Set(entries.map { $0.id })
//		
//		let missing = itemIDs.subtracting(articleIDs)
//		
//		XCTAssertEqual(items.count, entries.count)
//		XCTAssertTrue(missing.isEmpty, "Failed to create \(FeedlyEntry.self) values from objects in the JSON with these ids.")
//	}
//}
