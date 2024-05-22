//
//  FeedlyCreateFeedsForCollectionFoldersOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 22/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//class FeedlyCreateFeedsForCollectionFoldersOperationTests: XCTestCase {
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
//	class FeedsAndFoldersProvider: FeedlyFeedsAndFoldersProviding {
//		var feedsAndFolders = [([FeedlyFeed], Folder)]()
//	}
//	
//	func testAddFeeds() {
//		let feedsForFolderOne = [
//			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
//			FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)
//		]
//		
//		let feedsForFolderTwo = [
//			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
//			FeedlyFeed(id: "feed/3", title: "Feed Three", updated: nil, website: nil),
//		]
//		
//		let folderOne: (name: String, id: String) = ("FolderOne", "folder/1")
//		let folderTwo: (name: String, id: String) = ("FolderTwo", "folder/2")
//		let namesAndFeeds = [(folderOne, feedsForFolderOne), (folderTwo, feedsForFolderTwo)]
//		
//		let provider = FeedsAndFoldersProvider()
//		provider.feedsAndFolders = namesAndFeeds.map { (folder, feeds) in
//			let accountFolder = account.ensureFolder(with: folder.name)!
//			accountFolder.externalID = folder.id
//			return (feeds, accountFolder)
//		}
//		
//		let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: provider, log: support.log)
//		let completionExpectation = expectation(description: "Did Finish")
//		createFeeds.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		XCTAssertTrue(account.flattenedFeeds().isEmpty, "Expected empty account.")
//		
//		MainThreadOperationQueue.shared.add(createFeeds)
//		
//		waitForExpectations(timeout: 2)
//		
//		let feedIDs = Set([feedsForFolderOne, feedsForFolderTwo]
//			.flatMap { $0 }
//			.map { $0.id })
//		
//		let feedTitles = Set([feedsForFolderOne, feedsForFolderTwo]
//			.flatMap { $0 }
//			.map { $0.title })
//		
//		let accountFeeds = account.flattenedFeeds()
//		let ingestedIDs = Set(accountFeeds.map { $0.feedID })
//		let ingestedTitles = Set(accountFeeds.map { $0.nameForDisplay })
//		
//		let missingIDs = feedIDs.subtracting(ingestedIDs)
//		let missingTitles = feedTitles.subtracting(ingestedTitles)
//		
//		XCTAssertTrue(missingIDs.isEmpty, "Failed to ingest feeds with these ids.")
//		XCTAssertTrue(missingTitles.isEmpty, "Failed to ingest feeds with these titles.")
//		
//		let expectedFolderAndFeedIDs = namesAndFeeds
//			.sorted { $0.0.id < $1.0.id }
//			.map { folder, feeds -> [String: [String]] in
//			return [folder.id: feeds.map { $0.id }.sorted(by: <)]
//		}
//		
//		let ingestedFolderAndFeedIDs = (account.folders ?? Set())
//			.sorted { $0.externalID! < $1.externalID! }
//			.compactMap { folder -> [String: [String]]? in
//				return [folder.externalID!: folder.topLevelFeeds.map { $0.feedID }.sorted(by: <)]
//		}
//		
//		XCTAssertEqual(expectedFolderAndFeedIDs, ingestedFolderAndFeedIDs, "Did not ingest feeds in their corresponding folders.")
//	}
//	
//	func testRemoveFeeds() {
//		let folderOne: (name: String, id: String) = ("FolderOne", "folder/1")
//		let folderTwo: (name: String, id: String) = ("FolderTwo", "folder/2")
//		let feedToRemove = FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil)
//		
//		var feedsForFolderOne = [
//			feedToRemove,
//			FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)
//		]
//		
//		var feedsForFolderTwo = [
//			feedToRemove,
//			FeedlyFeed(id: "feed/3", title: "Feed Three", updated: nil, website: nil),
//		]
//		
//		// Add initial content.
//		do {
//			let namesAndFeeds = [(folderOne, feedsForFolderOne), (folderTwo, feedsForFolderTwo)]
//			
//			let provider = FeedsAndFoldersProvider()
//			provider.feedsAndFolders = namesAndFeeds.map { (folder, feeds) in
//				let accountFolder = account.ensureFolder(with: folder.name)!
//				accountFolder.externalID = folder.id
//				return (feeds, accountFolder)
//			}
//			
//			let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: provider, log: support.log)
//			let completionExpectation = expectation(description: "Did Finish")
//			createFeeds.completionBlock = { _ in
//				completionExpectation.fulfill()
//			}
//			
//			XCTAssertTrue(account.flattenedFeeds().isEmpty, "Expected empty account.")
//			
//			MainThreadOperationQueue.shared.add(createFeeds)
//			
//			waitForExpectations(timeout: 2)
//		}
//		
//		feedsForFolderOne.removeAll { $0.id == feedToRemove.id }
//		feedsForFolderTwo.removeAll { $0.id == feedToRemove.id }
//		let namesAndFeeds = [(folderOne, feedsForFolderOne), (folderTwo, feedsForFolderTwo)]
//		
//		let provider = FeedsAndFoldersProvider()
//		provider.feedsAndFolders = namesAndFeeds.map { (folder, feeds) in
//			let accountFolder = account.ensureFolder(with: folder.name)!
//			accountFolder.externalID = folder.id
//			return (feeds, accountFolder)
//		}
//		
//		let removeFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: provider, log: support.log)
//		let completionExpectation = expectation(description: "Did Finish")
//		removeFeeds.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(removeFeeds)
//		
//		waitForExpectations(timeout: 2)
//		
//		let feedIDs = Set([feedsForFolderOne, feedsForFolderTwo]
//			.flatMap { $0 }
//			.map { $0.id })
//		
//		let feedTitles = Set([feedsForFolderOne, feedsForFolderTwo]
//			.flatMap { $0 }
//			.map { $0.title })
//		
//		let accountFeeds = account.flattenedFeeds()
//		let ingestedIDs = Set(accountFeeds.map { $0.feedID })
//		let ingestedTitles = Set(accountFeeds.map { $0.nameForDisplay })
//		
//		XCTAssertEqual(ingestedIDs.count, feedIDs.count)
//		XCTAssertEqual(ingestedTitles.count, feedTitles.count)
//		
//		let missingIDs = feedIDs.subtracting(ingestedIDs)
//		let missingTitles = feedTitles.subtracting(ingestedTitles)
//		
//		XCTAssertTrue(missingIDs.isEmpty, "Failed to ingest feeds with these ids.")
//		XCTAssertTrue(missingTitles.isEmpty, "Failed to ingest feeds with these titles.")
//		
//		let expectedFolderAndFeedIDs = namesAndFeeds
//			.sorted { $0.0.id < $1.0.id }
//			.map { folder, feeds -> [String: [String]] in
//			return [folder.id: feeds.map { $0.id }.sorted(by: <)]
//		}
//		
//		let ingestedFolderAndFeedIDs = (account.folders ?? Set())
//			.sorted { $0.externalID! < $1.externalID! }
//			.compactMap { folder -> [String: [String]]? in
//				return [folder.externalID!: folder.topLevelFeeds.map { $0.feedID }.sorted(by: <)]
//		}
//		
//		XCTAssertEqual(expectedFolderAndFeedIDs, ingestedFolderAndFeedIDs, "Did not ingest feeds to their corresponding folders.")
//	}
//}
