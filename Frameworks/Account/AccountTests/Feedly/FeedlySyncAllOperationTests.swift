//
//  FeedlySyncAllOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 30/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSWeb
import RSCore

class FeedlySyncAllOperationTests: XCTestCase {
	
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
	
	func testCancel() {
		let markArticlesService = TestMarkArticlesService()
		markArticlesService.didMarkExpectation = expectation(description: "Set Article Statuses")
		markArticlesService.didMarkExpectation?.isInverted = true
		
		let getStreamIdsService = TestGetStreamIdsService()
		getStreamIdsService.getStreamIdsExpectation = expectation(description: "Get Unread Article Identifiers")
		getStreamIdsService.getStreamIdsExpectation?.isInverted = true
		
		let getCollectionsService = TestGetCollectionsService()
		getCollectionsService.getCollectionsExpectation = expectation(description: "Get User's Collections")
		getCollectionsService.getCollectionsExpectation?.isInverted = true
		
		let getGlobalStreamContents = TestGetStreamContentsService()
		getGlobalStreamContents.getStreamContentsExpectation = expectation(description: "Get Contents of global.all")
		getGlobalStreamContents.getStreamContentsExpectation?.isInverted = true
		
		let getStarredIds = TestGetStreamIdsService()
		getStarredIds.getStreamIdsExpectation = expectation(description: "Get Ids of global.saved")
		getStarredIds.getStreamIdsExpectation?.isInverted = true
		
		let getEntriesService = TestGetEntriesService()
		getEntriesService.getEntriesExpectation = expectation(description: "Get Entries")
		getEntriesService.getEntriesExpectation?.isInverted = true
		
		let progress = DownloadProgress(numberOfTasks: 0)
		let _ = expectationForCompletion(of: progress)
		
		let container = support.makeTestDatabaseContainer()
		let syncAll = FeedlySyncAllOperation(account: account,
										  credentials: support.accessToken,
										  lastSuccessfulFetchStartDate: nil,
										  markArticlesService: markArticlesService,
										  getUnreadService: getStreamIdsService,
										  getCollectionsService: getCollectionsService,
										  getStreamContentsService: getGlobalStreamContents,
										  getStarredService: getStarredIds,
										  getStreamIdsService: getStreamIdsService,
										  getEntriesService: getEntriesService,
										  database: container.database,
										  downloadProgress: progress,
										  log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		syncAll.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		let syncCompletionExpectation = expectation(description: "Did Finish Sync")
		syncCompletionExpectation.isInverted = true
		syncAll.syncCompletionHandler = { result in
			switch result {
			case .success:
				XCTFail("Sync operation was cancelled, not successful.")
			case .failure:
				XCTFail("Sync operation should cancel silently.")
				break
			}
			syncCompletionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.addOperation(syncAll)
		
		XCTAssertTrue(progress.numberOfTasks > 1)
		
		syncAll.cancel()
		
		waitForExpectations(timeout: 2)
		
		XCTAssertNil(syncAll.syncCompletionHandler, "Expected completion handler to be destroyed after completion.")
	}
	
	private var transport = TestTransport()
	lazy var caller: FeedlyAPICaller = {
		let caller = FeedlyAPICaller(transport: transport, api: .sandbox)
		caller.credentials = support.accessToken
		return caller
	}()
	
	func testSyncing() throws {
		performInitialSync()
		try verifyInitialSync()
		
		performChangeStatuses()
		try verifyChangeStatuses()
		
		performChangeStatusesAgain()
		try verifyChangeStatusesAgain()
		
		performAddFeedsAndFolders()
		try verifyAddFeedsAndFolders()
	}
	
	// MARK: 1 - Initial Sync
	
	private func loadMockData(inSubdirectoryNamed subdirectory: String) {
		let provider = FeedlyMockResponseProvider(findingMocksIn: subdirectory)
		transport.mockResponseFileUrlProvider = provider
		
		let progress = DownloadProgress(numberOfTasks: 0)
		let _ = expectationForCompletion(of: progress)
		
		// lastSuccessfulFetchStartDate does not matter for the test, content will always be the same.
		// It is tested in `FeedlyGetStreamContentsOperationTests`.
		let syncAll = FeedlySyncAllOperation(account: account,
											 credentials: support.accessToken,
											 caller: caller,
											 database: databaseContainer.database,
											 lastSuccessfulFetchStartDate: nil,
											 downloadProgress: progress,
											 log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		syncAll.completionBlock = { _ in
			completionExpectation.fulfill()
		}
				
		MainThreadOperationQueue.shared.addOperation(syncAll)
		
		XCTAssertTrue(progress.numberOfTasks > 1)
		
		waitForExpectations(timeout: 5)
		
		XCTAssertTrue(progress.numberOfTasks == 0)
	}
	
	func performInitialSync() {
		loadMockData(inSubdirectoryNamed: "feedly-1-initial")
	}
	
	func verifyInitialSync() throws {
		let subdirectory = "feedly-1-initial"
		support.checkFoldersAndFeeds(in: account, againstCollectionsAndFeedsInJSONNamed: "collections", subdirectory: subdirectory)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "global.all", subdirectory: subdirectory)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "global.all@MTZkOTdkZWQ1NzM6NTE2OjUzYjgyNmEy", subdirectory: subdirectory)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds", subdirectory: subdirectory, testCase: self)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds@MTZkOTRhOTNhZTQ6MzExOjUzYjgyNmEy", subdirectory: subdirectory, testCase: self)
		support.checkStarredStatuses(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory, testCase: self)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory)
	}
	
	// MARK: 2 - Change Statuses
	
	func performChangeStatuses() {
		loadMockData(inSubdirectoryNamed: "feedly-2-changestatuses")
	}
	
	func verifyChangeStatuses() throws {
		let subdirectory = "feedly-2-changestatuses"
		support.checkFoldersAndFeeds(in: account, againstCollectionsAndFeedsInJSONNamed: "collections", subdirectory: subdirectory)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "global.all", subdirectory: subdirectory)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds", subdirectory: subdirectory, testCase: self)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds@MTZkOTJkNjIwM2Q6MTEzYjpkNDUwNjA3MQ==", subdirectory: subdirectory, testCase: self)
		support.checkStarredStatuses(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory, testCase: self)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory)
	}
	
	// MARK: 3 - Change Statuses Again
	
	func performChangeStatusesAgain() {
		loadMockData(inSubdirectoryNamed: "feedly-3-changestatusesagain")
	}
	
	func verifyChangeStatusesAgain() throws {
		let subdirectory = "feedly-3-changestatusesagain"
		support.checkFoldersAndFeeds(in: account, againstCollectionsAndFeedsInJSONNamed: "collections", subdirectory: subdirectory)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "global.all", subdirectory: subdirectory)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds", subdirectory: subdirectory, testCase: self)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds@MTZkOGRlMjVmM2M6M2YyOmQ0NTA2MDcx", subdirectory: subdirectory, testCase: self)
		support.checkStarredStatuses(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory, testCase: self)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory)
	}
	
	// MARK: 4 - Add Feeds and Folders
	
	func performAddFeedsAndFolders() {
		loadMockData(inSubdirectoryNamed: "feedly-4-addfeedsandfolders")
	}
	
	func verifyAddFeedsAndFolders() throws {
		let subdirectory = "feedly-4-addfeedsandfolders"
		support.checkFoldersAndFeeds(in: account, againstCollectionsAndFeedsInJSONNamed: "collections", subdirectory: subdirectory)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "global.all", subdirectory: subdirectory)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds", subdirectory: subdirectory, testCase: self)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds@MTZkOTE3YTRlMzQ6YWZjOmQ0NTA2MDcx", subdirectory: subdirectory, testCase: self)
		support.checkStarredStatuses(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory, testCase: self)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory)
	}
	
	// MARK: 5 - Remove Feeds and Folders
	
	func performRemoveFeedsAndFolders() {
		loadMockData(inSubdirectoryNamed: "feedly-5-removefeedsandfolders")
	}
	
	func verifyRemoveFeedsAndFolders() throws {
		let subdirectory = "feedly-5-removefeedsandfolders"
		support.checkFoldersAndFeeds(in: account, againstCollectionsAndFeedsInJSONNamed: "collections", subdirectory: subdirectory)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "global.all", subdirectory: subdirectory)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds", subdirectory: subdirectory, testCase: self)
		support.checkUnreadStatuses(in: account, againstIdsInStreamInJSONNamed: "unreadIds@MTZkOGRlMjVmM2M6M2YxOmQ0NTA2MDcx", subdirectory: subdirectory, testCase: self)
		support.checkStarredStatuses(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory, testCase: self)
		try support.checkArticles(in: account, againstItemsInStreamInJSONNamed: "starred", subdirectory: subdirectory)
	}
	
	// MARK: Downloading Test Data
	
	var lastSuccessfulFetchStartDate: Date?
	lazy var databaseContainer: FeedlyTestSupport.TestDatabaseContainer = {
		return support.makeTestDatabaseContainer()
	}()
	
	func downloadTestData() {
		let caller = FeedlyAPICaller(transport: URLSession.webserviceTransport(), api: .sandbox)
		let credentials = Credentials(type: .oauthAccessToken, username: "<#USERNAME#>", secret: "<#SECRET#>")
		caller.credentials = credentials
		
		let progress = DownloadProgress(numberOfTasks: 0)
		let _ = expectationForCompletion(of: progress)
		
		let syncAll = FeedlySyncAllOperation(account: account, credentials: credentials, caller: caller, database: databaseContainer.database, lastSuccessfulFetchStartDate: lastSuccessfulFetchStartDate, downloadProgress: progress, log: support.log)
		
		// If this expectation is not fulfilled, the operation is not calling `didFinish`.
		let completionExpectation = expectation(description: "Did Finish")
		syncAll.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		lastSuccessfulFetchStartDate = Date()
		
		MainThreadOperationQueue.shared.addOperation(syncAll)
		
		XCTAssertTrue(progress.numberOfTasks > 1)
		
		waitForExpectations(timeout: 60)
		
		XCTAssertTrue(progress.numberOfTasks == 0)
	}
	
	// Prefix with "test" to manually run this particular function, e.g.: func test_getTestData()
	func getTestData() {
		// Add a breakpoint on the `print` statements and start a proxy server on your Mac.
		// 1. In Feedly sandbox, perform the actions implied by the string in the print statement.
		// 2. In the proxy server app, such as Charles, clear requests and responses and filter by "sandbox".
		// 3. In Xcode, hit continue in the Debugger so the test requests the data.
		// 4. Save the responses captured by the proxy.
		print("Prepare for initial sync.")
		downloadTestData()
		
		assert(lastSuccessfulFetchStartDate != nil)
		
		print("Read/unread, star and unstar some articles.")
		downloadTestData()
		
		print("Read/unread, star and unstar some articles again.")
		downloadTestData()
		
		print("Add Feeds and Folders.")
		downloadTestData()
		
		print("Rename and Remove Feeds and Folders.")
		downloadTestData()
	}
}
