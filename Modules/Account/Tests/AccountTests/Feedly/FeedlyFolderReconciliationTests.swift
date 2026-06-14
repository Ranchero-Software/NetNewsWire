//
//  FeedlyFolderReconciliationTests.swift
//  AccountTests
//
//  Created by Brent Simmons on 5/29/26.
//

import XCTest
@testable import Account

@MainActor final class FeedlyFolderReconciliationTests: XCTestCase {

	private var account: Account!
	private let accountManager = TestAccountManager()

	override func setUp() async throws {
		try await super.setUp()
		account = accountManager.createAccount(type: .feedly)
	}

	override func tearDown() async throws {
		if let account {
			accountManager.deleteAccount(account)
		}
		try await super.tearDown()
	}

	// MARK: - mirrorCollectionsAsFolders

	func testMirrorCollectionsAsFoldersAddsFolders() {
		let collections = [
			FeedlyCollection(feeds: [], label: "One", id: "collections/1"),
			FeedlyCollection(feeds: [], label: "Two", id: "collections/2")
		]

		_ = mirrorCollectionsAsFolders(collections, in: account)

		let folders = account.folders ?? Set()
		let folderNames = Set(folders.compactMap { $0.nameForDisplay })
		let folderExternalIDs = Set(folders.compactMap { $0.externalID })

		XCTAssertEqual(folderNames, Set(["One", "Two"]))
		XCTAssertEqual(folderExternalIDs, Set(["collections/1", "collections/2"]))
	}

	func testMirrorCollectionsAsFoldersRemovesFoldersWithoutCollections() {
		_ = mirrorCollectionsAsFolders([
			FeedlyCollection(feeds: [], label: "One", id: "collections/1"),
			FeedlyCollection(feeds: [], label: "Two", id: "collections/2")
		], in: account)

		// Now remove all collections; both folders should disappear.
		let pairs = mirrorCollectionsAsFolders([], in: account)

		XCTAssertTrue(pairs.isEmpty)

		let folders = account.folders ?? Set()
		XCTAssertTrue(folders.isEmpty, "Folders should be removed when their collection no longer exists.")
	}

	func testMirrorCollectionsAsFoldersReturnsCollectionFeedsPairedWithFolders() {
		let feedsForOne = [
			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
			FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)
		]
		let feedsForTwo = [
			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
			FeedlyFeed(id: "feed/3", title: "Feed Three", updated: nil, website: nil)
		]
		let collections = [
			FeedlyCollection(feeds: feedsForOne, label: "One", id: "collections/1"),
			FeedlyCollection(feeds: feedsForTwo, label: "Two", id: "collections/2")
		]

		let pairs = mirrorCollectionsAsFolders(collections, in: account)

		XCTAssertEqual(pairs.count, 2)

		let pairedIDs = pairs.compactMap { pair -> [String: [String]]? in
			guard let id = pair.folder.externalID else {
				return nil
			}
			return [id: pair.feeds.map { $0.id }.sorted()]
		}
		let expectedIDs = collections.map { collection in
			[collection.id: collection.feeds.map { $0.id }.sorted()]
		}
		XCTAssertEqual(pairedIDs, expectedIDs)
	}

	// MARK: - syncFeedsForCollectionFolders

	func testSyncFeedsForCollectionFoldersAddsFeeds() {
		let feedsForOne = [
			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
			FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)
		]
		let feedsForTwo = [
			FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
			FeedlyFeed(id: "feed/3", title: "Feed Three", updated: nil, website: nil)
		]
		let folderOne = makeFolder(name: "FolderOne", externalID: "folder/1")
		let folderTwo = makeFolder(name: "FolderTwo", externalID: "folder/2")
		let pairs = [(feedsForOne, folderOne), (feedsForTwo, folderTwo)]

		XCTAssertTrue(account.flattenedFeeds().isEmpty)

		syncFeedsForCollectionFolders(pairs, in: account)

		let accountFeeds = account.flattenedFeeds()
		let ingestedIDs = Set(accountFeeds.map { $0.feedID })
		let ingestedTitles = Set(accountFeeds.map { $0.nameForDisplay })

		XCTAssertEqual(ingestedIDs, Set(["feed/1", "feed/2", "feed/3"]))
		XCTAssertEqual(ingestedTitles, Set(["Feed One", "Feed Two", "Feed Three"]))

		assertFolder(folderOne, contains: ["feed/1", "feed/2"])
		assertFolder(folderTwo, contains: ["feed/1", "feed/3"])
	}

	func testSyncFeedsForCollectionFoldersRemovesFeedsNoLongerInCollection() {
		let shared = FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil)
		let folderOne = makeFolder(name: "FolderOne", externalID: "folder/1")
		let folderTwo = makeFolder(name: "FolderTwo", externalID: "folder/2")

		// Seed: both folders have feed/1.
		syncFeedsForCollectionFolders([
			([shared, FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)], folderOne),
			([shared, FeedlyFeed(id: "feed/3", title: "Feed Three", updated: nil, website: nil)], folderTwo)
		], in: account)

		XCTAssertEqual(Set(account.flattenedFeeds().map { $0.feedID }), Set(["feed/1", "feed/2", "feed/3"]))

		// Drop feed/1 from both collections; the remaining feeds should still belong to the right folders.
		syncFeedsForCollectionFolders([
			([FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)], folderOne),
			([FeedlyFeed(id: "feed/3", title: "Feed Three", updated: nil, website: nil)], folderTwo)
		], in: account)

		assertFolder(folderOne, contains: ["feed/2"])
		assertFolder(folderTwo, contains: ["feed/3"])
	}

	func testSyncFeedsForCollectionFoldersRenamesFeedWhenCollectionTitleChanges() {
		let folder = makeFolder(name: "Folder", externalID: "folder/1")

		syncFeedsForCollectionFolders([
			([FeedlyFeed(id: "feed/1", title: "Original Title", updated: nil, website: nil)], folder)
		], in: account)

		let originalFeed = folder.existingFeed(withFeedID: "feed/1")
		XCTAssertEqual(originalFeed?.nameForDisplay, "Original Title")

		syncFeedsForCollectionFolders([
			([FeedlyFeed(id: "feed/1", title: "Updated Title", updated: nil, website: nil)], folder)
		], in: account)

		let updatedFeed = folder.existingFeed(withFeedID: "feed/1")
		XCTAssertEqual(updatedFeed?.nameForDisplay, "Updated Title")
		XCTAssertTrue(originalFeed === updatedFeed, "Renaming a feed should reuse the existing Feed instance.")
	}

	// MARK: - Combined behavior

	func testMirrorThenRemoveAllRemovesFeedsToo() {
		let collections = [
			FeedlyCollection(
				feeds: [
					FeedlyFeed(id: "feed/1", title: "Feed One", updated: nil, website: nil),
					FeedlyFeed(id: "feed/2", title: "Feed Two", updated: nil, website: nil)
				],
				label: "One",
				id: "collections/1"
			)
		]
		let pairs = mirrorCollectionsAsFolders(collections, in: account)
		syncFeedsForCollectionFolders(pairs, in: account)

		XCTAssertFalse(account.flattenedFeeds().isEmpty)

		// Removing the collection should remove its folder, and the feeds should go with it.
		_ = mirrorCollectionsAsFolders([], in: account)

		XCTAssertTrue(account.flattenedFeeds().isEmpty)
	}

	// MARK: - Helpers

	private func makeFolder(name: String, externalID: String) -> Folder {
		let folder = account.ensureFolder(with: name)!
		folder.externalID = externalID
		return folder
	}

	private func assertFolder(_ folder: Folder, contains feedIDs: Set<String>, file: StaticString = #filePath, line: UInt = #line) {
		let actual = Set(folder.topLevelFeeds.map { $0.feedID })
		XCTAssertEqual(actual, feedIDs, "Folder \(folder.nameForDisplay) had unexpected feeds.", file: file, line: line)
	}
}
