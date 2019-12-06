//
//  FeedlyMirrorCollectionsAsFoldersOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 22/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class FeedlyMirrorCollectionsAsFoldersOperationTests: XCTestCase {
	
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
	
	class CollectionsProvider: FeedlyCollectionProviding {
		var collections = [
			FeedlyCollection(feeds: [], label: "One", id: "collections/1"),
			FeedlyCollection(feeds: [], label: "Two", id: "collections/2")
		]
	}
	
	func testAddsFolders() {
		let provider = CollectionsProvider()
		let mirrorOperation = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: provider, log: support.log)
		let completionExpectation = expectation(description: "Did Finish")
		mirrorOperation.completionBlock = {
			completionExpectation.fulfill()
		}
		
		XCTAssertTrue(mirrorOperation.collectionsAndFolders.isEmpty)
		XCTAssertTrue(mirrorOperation.feedsAndFolders.isEmpty)
		
		OperationQueue.main.addOperation(mirrorOperation)
		
		waitForExpectations(timeout: 2)
		
		let folders = account.folders ?? Set()
		let folderNames = Set(folders.compactMap { $0.nameForDisplay })
		let folderExternalIds = Set(folders.compactMap { $0.externalID })
		
		let collectionLabels = Set(provider.collections.map { $0.label })
		let collectionIds = Set(provider.collections.map { $0.id })
		
		let missingNames = collectionLabels.subtracting(folderNames)
		let missingIds = collectionIds.subtracting(folderExternalIds)
		
		XCTAssertTrue(missingNames.isEmpty, "Collections with these labels have no corresponding folder.")
		XCTAssertTrue(missingIds.isEmpty, "Collections with these ids have no corresponding folder.")
		XCTAssertEqual(mirrorOperation.collectionsAndFolders.count, provider.collections.count, "Mismatch between collections and folders.")
	}
	
	func testRemovesFolders() {
		let provider = CollectionsProvider()
		
		do {
			let addFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: provider, log: support.log)
			let completionExpectation = expectation(description: "Did Finish")
			addFolders.completionBlock = {
				completionExpectation.fulfill()
			}
			
			OperationQueue.main.addOperation(addFolders)
			
			waitForExpectations(timeout: 2)
		}
		
		// Now that the folders are added, remove them all.
		provider.collections = []
		
		let removeFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: provider, log: support.log)
		let completionExpectation = expectation(description: "Did Finish")
		removeFolders.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(removeFolders)
		
		waitForExpectations(timeout: 2)
		
		let folders = account.folders ?? Set()
		let folderNames = Set(folders.compactMap { $0.nameForDisplay })
		let folderExternalIds = Set(folders.compactMap { $0.externalID })
		
		let collectionLabels = Set(provider.collections.map { $0.label })
		let collectionIds = Set(provider.collections.map { $0.id })
		
		let remainingNames = folderNames.subtracting(collectionLabels)
		let remainingIds = folderExternalIds.subtracting(collectionIds)
		
		XCTAssertTrue(remainingNames.isEmpty, "Folders with these names remain with no corresponding collection.")
		XCTAssertTrue(remainingIds.isEmpty, "Folders with these ids remain with no corresponding collection.")
		
		XCTAssertTrue(removeFolders.collectionsAndFolders.isEmpty)
		XCTAssertTrue(removeFolders.feedsAndFolders.isEmpty)
	}
	
	class CollectionsAndFeedsProvider: FeedlyCollectionProviding {
		var feedsForCollectionOne = [
			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
			FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)
		]
		
		var feedsForCollectionTwo = [
			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
			FeedlyFeed(id: "feed/3", title: "Feed Three", updated: nil, website: nil),
		]
		
		var collections: [FeedlyCollection] {
			return [
				FeedlyCollection(feeds: feedsForCollectionOne, label: "One", id: "collections/1"),
				FeedlyCollection(feeds: feedsForCollectionTwo, label: "Two", id: "collections/2")
			]
		}
	}
	
	func testFeedMappedToFolders() {
		let provider = CollectionsAndFeedsProvider()
		let mirrorOperation = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: provider, log: support.log)
		let completionExpectation = expectation(description: "Did Finish")
		mirrorOperation.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(mirrorOperation)
		
		waitForExpectations(timeout: 2)
		
		let folders = account.folders ?? Set()
		let folderNames = Set(folders.compactMap { $0.nameForDisplay })
		let folderExternalIds = Set(folders.compactMap { $0.externalID })
		
		let collectionLabels = Set(provider.collections.map { $0.label })
		let collectionIds = Set(provider.collections.map { $0.id })
		
		let missingNames = collectionLabels.subtracting(folderNames)
		let missingIds = collectionIds.subtracting(folderExternalIds)
		
		XCTAssertTrue(missingNames.isEmpty, "Collections with these labels have no corresponding folder.")
		XCTAssertTrue(missingIds.isEmpty, "Collections with these ids have no corresponding folder.")
		
		let collectionIdsAndFeedIds = provider.collections.map { collection -> [String:[String]] in
			return [collection.id: collection.feeds.map { $0.id }.sorted(by: <)]
		}
		
		let folderIdsAndFeedIds = mirrorOperation.feedsAndFolders.compactMap { feeds, folder -> [String:[String]]? in
			guard let id = folder.externalID else {
				return nil
			}
			return [id: feeds.map { $0.id }.sorted(by: <)]
		}
		
		XCTAssertEqual(collectionIdsAndFeedIds, folderIdsAndFeedIds, "Did not map folders to feeds correctly.")
	}
	
	func testRemovingFolderRemovesFeeds() {
		do {
			let provider = CollectionsAndFeedsProvider()
			let addFoldersAndFeeds = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: provider, log: support.log)
			
			let createFeeds = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: addFoldersAndFeeds, log: support.log)
			createFeeds.addDependency(addFoldersAndFeeds)
			
			let completionExpectation = expectation(description: "Did Finish")
			createFeeds.completionBlock = {
				completionExpectation.fulfill()
			}
			
			OperationQueue.main.addOperations([addFoldersAndFeeds, createFeeds], waitUntilFinished: false)
			
			waitForExpectations(timeout: 2)
			
			XCTAssertFalse(account.flattenedWebFeeds().isEmpty, "Expected account to have feeds.")
		}
		
		// Now that the folders are added, remove them all.
		let provider = CollectionsProvider()
		provider.collections = []
		
		let removeFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: provider, log: support.log)
		let completionExpectation = expectation(description: "Did Finish")
		removeFolders.completionBlock = {
			completionExpectation.fulfill()
		}
		
		OperationQueue.main.addOperation(removeFolders)
		
		waitForExpectations(timeout: 2)
		
		let feeds = account.flattenedWebFeeds()
		
		XCTAssertTrue(feeds.isEmpty)
	}
}
