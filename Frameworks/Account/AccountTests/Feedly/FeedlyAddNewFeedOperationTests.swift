//
//  FeedlyAddNewFeedOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 2/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSWeb
import RSCore

class FeedlyAddNewFeedOperationTests: XCTestCase {

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
	
	private var transport = TestTransport()
	lazy var caller: FeedlyAPICaller = {
		let caller = FeedlyAPICaller(transport: transport, api: .sandbox)
		caller.credentials = support.accessToken
		return caller
	}()
	
	private func getFolderByLoadingInitialContent() -> Folder? {
		let subdirectory = "feedly-add-new-feed"
		let provider = InitialMockResponseProvider(findingMocksIn: subdirectory)
		
		transport.mockResponseFileUrlProvider = provider
		let getCollections = FeedlyGetCollectionsOperation(service: caller, log: support.log)
		
		let mirrorCollectionsAsFolders = FeedlyMirrorCollectionsAsFoldersOperation(account: account, collectionsProvider: getCollections, log: support.log)
		MainThreadOperationQueue.shared.make(mirrorCollectionsAsFolders, dependOn: getCollections)

		let createFolders = FeedlyCreateFeedsForCollectionFoldersOperation(account: account, feedsAndFoldersProvider: mirrorCollectionsAsFolders, log: support.log)
		MainThreadOperationQueue.shared.make(createFolders, dependOn: mirrorCollectionsAsFolders)
		
		let completionExpectation = expectation(description: "Did Finish")
		createFolders.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperations([getCollections, mirrorCollectionsAsFolders, createFolders])
		
		waitForExpectations(timeout: 2)
		
		support.checkFoldersAndFeeds(in: account, againstCollectionsAndFeedsInJSONNamed: "emptyCollections", subdirectory: subdirectory)
		
		guard let folder = account.folders?.first else {
			XCTFail("Unable to load test folder to add a feed into.")
			return nil
		}
		
		XCTAssertEqual(folder.topLevelWebFeeds.count, 0)
		
		return folder
	}
	
	func expectationForCompletion(of progress: DownloadProgress) -> XCTestExpectation {
		return expectation(forNotification: .DownloadProgressDidChange, object: progress) { notification -> Bool in
			guard let progress = notification.object as? DownloadProgress else {
				return false
			}
			// We want to assert the progress completes.
			if progress.isComplete {
				return true
			}
			return false
		}
	}
	
	let searchUrl = "https://macrumors.com"
	
	func testCancel() {
		guard let folder = getFolderByLoadingInitialContent() else {
			return
		}
		
		let progress = DownloadProgress(numberOfTasks: 0)
		let container = support.makeTestDatabaseContainer()
		let _ = expectationForCompletion(of: progress)
		
		let addNewFeed = try! FeedlyAddNewFeedOperation(account: account,
														credentials: support.accessToken,
														url: searchUrl,
														feedName: nil,
														searchService: caller,
														addToCollectionService: caller,
														syncUnreadIdsService: caller,
														getStreamContentsService: caller,
														database: container.database,
														container: folder,
														progress: progress,
														log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		addNewFeed.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(addNewFeed)
		
		XCTAssert(progress.numberRemaining > 0)
		
		addNewFeed.cancel()
		
		waitForExpectations(timeout: 2)
		
		XCTAssert(progress.isComplete)
	}
	
	func testAddNewFeedSuccess() throws {
		guard let folder = getFolderByLoadingInitialContent() else {
			return
		}
		
		let progress = DownloadProgress(numberOfTasks: 0)
		let container = support.makeTestDatabaseContainer()
		let _ = expectationForCompletion(of: progress)
		
		let subdirectory = "feedly-add-new-feed"
		let searchUrl = self.searchUrl
		let provider = MockResponseProvider(findingMocksIn: subdirectory)
		provider.searchQueryHandler = { query in
			XCTAssertEqual(query, searchUrl)
		}
		
		transport.mockResponseFileUrlProvider = provider
		
		let addNewFeed = try! FeedlyAddNewFeedOperation(account: account,
														credentials: support.accessToken,
														url: searchUrl,
														feedName: nil,
														searchService: caller,
														addToCollectionService: caller,
														syncUnreadIdsService: caller,
														getStreamContentsService: caller,
														database: container.database,
														container: folder,
														progress: progress,
														log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		addNewFeed.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(addNewFeed)
		
		XCTAssert(progress.numberRemaining > 0)
				
		waitForExpectations(timeout: 2)
		
		XCTAssert(progress.isComplete)
		
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "feedStream", subdirectory: subdirectory)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds", subdirectory: subdirectory, testCase: self)
	}
	
	class TestFeedlyAddFeedToCollectionService: FeedlyAddFeedToCollectionService {
		var mockResult: Result<[FeedlyFeed], Error>?
		var addFeedExpectation: XCTestExpectation?
		var parameterTester: ((FeedlyFeedResourceId, String?, String) -> ())?
		
		func addFeed(with feedId: FeedlyFeedResourceId, title: String?, toCollectionWith collectionId: String, completion: @escaping (Result<[FeedlyFeed], Error>) -> ()) {
			guard let result = mockResult else {
				XCTFail("Missing mock result. Test may time out because the completion will not be called.")
				return
			}
			parameterTester?(feedId, title, collectionId)
			DispatchQueue.main.async {
				completion(result)
				self.addFeedExpectation?.fulfill()
			}
		}
	}
	
	func testAddNewFeedFailure() {
		guard let folder = getFolderByLoadingInitialContent() else {
			return
		}
		
		let progress = DownloadProgress(numberOfTasks: 0)
		let container = support.makeTestDatabaseContainer()
		let _ = expectationForCompletion(of: progress)
		
		let subdirectory = "feedly-add-new-feed"
		let searchUrl = self.searchUrl
		let feedName = "MacRumours with a \"u\" because I am Australian"
		let provider = MockResponseProvider(findingMocksIn: subdirectory)
		provider.searchQueryHandler = { query in
			XCTAssertEqual(query, searchUrl)
		}
		
		transport.mockResponseFileUrlProvider = provider
		
		let service = TestFeedlyAddFeedToCollectionService()
		service.mockResult = .failure(URLError(.timedOut))
		service.addFeedExpectation = expectation(description: "Add New Feed Called")
		service.parameterTester = { feedResource, title, collectionId in
			XCTAssertEqual(feedResource.id, "feed/http://feeds.macrumors.com/MacRumors-All")
			XCTAssertEqual(title, feedName)
			XCTAssertEqual(collectionId, folder.externalID)
		}
		
		let addNewFeed = try! FeedlyAddNewFeedOperation(account: account,
														credentials: support.accessToken,
														url: searchUrl,
														feedName: feedName,
														searchService: caller,
														addToCollectionService: service,
														syncUnreadIdsService: caller,
														getStreamContentsService: caller,
														database: container.database,
														container: folder,
														progress: progress,
														log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		addNewFeed.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(addNewFeed)
		
		XCTAssert(progress.numberRemaining > 0)
				
		waitForExpectations(timeout: 2)
		
		XCTAssert(progress.isComplete)
		
		XCTAssertEqual(folder.topLevelWebFeeds.count, 0)
	}
}

private class InitialMockResponseProvider: TestTransportMockResponseProviding {
	
	let subdirectory: String
	
	init(findingMocksIn subdirectory: String) {
		self.subdirectory = subdirectory
	}
		
	func mockResponseFileUrl(for components: URLComponents) -> URL? {
		let bundle = Bundle(for: type(of: self))
		
		// When we get a request for the initial collections content, use these results.
		if components.path.contains("/v3/collections") {
			return bundle.url(forResource: "emptyCollections", withExtension: "json", subdirectory: subdirectory)
		}
		
		return nil
	}
}


private class MockResponseProvider: TestTransportMockResponseProviding {
	
	let subdirectory: String
	
	init(findingMocksIn subdirectory: String) {
		self.subdirectory = subdirectory
	}
	
	var searchQueryHandler: ((String) -> ())?
	
	func mockResponseFileUrl(for components: URLComponents) -> URL? {
		let bundle = Bundle(for: type(of: self))
		
		let queryItems = components.queryItems ?? []
		let query = queryItems.first(where: { $0.name.contains("query") })?.value
		
		// When we get the search request, use these results.
		if components.path.contains("search/feeds") {
			if let query = query {
				searchQueryHandler?(query)
			} else {
				XCTFail("`query` missing from URL query items in search request: \(components)")
			}
			return bundle.url(forResource: "searchResults", withExtension: "json", subdirectory: subdirectory)
		}
		
		// When we get a request to add a feed, use these results.
		if components.path.contains("/v3/collections") && components.path.contains("/feeds") {
			return bundle.url(forResource: "putFeed", withExtension: "json", subdirectory: subdirectory)
		}
		
		// When we get a request for the initial collections content, use these results.
		if components.path.contains("/v3/collections") {
			return bundle.url(forResource: "collections", withExtension: "json", subdirectory: subdirectory)
		}
		
		let continuation = queryItems.first(where: { $0.name.contains("continuation") })?.value
		
		// When we get a request for unread article ids, use these results.
		if components.path.contains("streams/ids") {
			
			// if there is a continuation, return the page for it
			if let continuation = continuation, let data = continuation.data(using: .utf8) {
				let base64 = data.base64EncodedString() // at least base64 can be used as a path component.
				return bundle.url(forResource: "unreadIds@\(base64)", withExtension: "json", subdirectory: subdirectory)
				
			} else {
				// return first page
				return bundle.url(forResource: "unreadIds", withExtension: "json", subdirectory: subdirectory)
			}
		}
		
		// When we get a request for the contents of the feed stream, use these results.
		if components.path.contains("streams/contents") {
			
			// if there is a continuation, return the page for it
			if let continuation = continuation, let data = continuation.data(using: .utf8) {
				let base64 = data.base64EncodedString() // at least base64 can be used as a path component.
				return bundle.url(forResource: "feedStream@\(base64)", withExtension: "json", subdirectory: subdirectory)
				
			} else {
				// return first page
				return bundle.url(forResource: "feedStream", withExtension: "json", subdirectory: subdirectory)
			}
		}
		
		return nil
	}
}
