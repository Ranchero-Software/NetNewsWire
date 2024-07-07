//
//  FeedlyGetStreamContentsOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 23/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//class FeedlyGetStreamContentsOperationTests: XCTestCase {
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
//	func testGetStreamContentsFailure() {
//		let service = TestGetStreamContentsService()
//		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
//		
//		let getStreamContents = FeedlyGetStreamContentsOperation(account: account, resource: resource, service: service, continuation: nil, newerThan: nil, unreadOnly: nil, log: support.log)
//		
//		service.mockResult = .failure(URLError(.fileDoesNotExist))
//		
//		let completionExpectation = expectation(description: "Did Finish")
//		getStreamContents.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(getStreamContents)
//		
//		waitForExpectations(timeout: 2)
//		
//		XCTAssertNil(getStreamContents.stream)
//	}
//	
//	func testValuesPassingForGetStreamContents() {
//		let service = TestGetStreamContentsService()
//		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
//		
//		let continuation: String? = "abcdefg"
//		let newerThan: Date? = Date(timeIntervalSinceReferenceDate: 86)
//		let unreadOnly: Bool? = true
//		
//		let getStreamContents = FeedlyGetStreamContentsOperation(account: account, resource: resource, service: service, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly, log: support.log)
//		
//		let mockStream = FeedlyStream(id: "stream/1", updated: nil, continuation: nil, items: [])
//		service.mockResult = .success(mockStream)
//		service.getStreamContentsExpectation = expectation(description: "Did Call Service")
//		service.parameterTester = { serviceResource, serviceContinuation, serviceNewerThan, serviceUnreadOnly in
//			// Verify these values given to the operation are passed to the service.
//			XCTAssertEqual(serviceResource.id, resource.id)
//			XCTAssertEqual(serviceContinuation, continuation)
//			XCTAssertEqual(serviceNewerThan, newerThan)
//			XCTAssertEqual(serviceUnreadOnly, unreadOnly)
//		}
//		
//		let completionExpectation = expectation(description: "Did Finish")
//		getStreamContents.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(getStreamContents)
//		
//		waitForExpectations(timeout: 2)
//		
//		guard let stream = getStreamContents.stream else {
//			XCTFail("\(FeedlyGetStreamContentsOperation.self) did not store the stream.")
//			return
//		}
//		
//		XCTAssertEqual(stream.id, mockStream.id)
//		XCTAssertEqual(stream.updated, mockStream.updated)
//		XCTAssertEqual(stream.continuation, mockStream.continuation)
//		
//		let streamIDs = stream.items.map { $0.id }
//		let mockStreamIDs = mockStream.items.map { $0.id }
//		XCTAssertEqual(streamIDs, mockStreamIDs)
//	}
//	
//	func testGetStreamContentsFromJSON() {
//		let support = FeedlyTestSupport()
//		let (transport, caller) = support.makeMockNetworkStack()
//		let jsonName = "JSON/feedly_macintosh_initial"
//		transport.testFiles["/v3/streams/contents"] = "\(jsonName).json"
//		
//		let resource = FeedlyCategoryResourceID(id: "user/f2f031bd-f3e3-4893-a447-467a291c6d1e/category/5ca4d61d-e55d-4999-a8d1-c3b9d8789815")
//		let getStreamContents = FeedlyGetStreamContentsOperation(account: account, resource: resource, service: caller, continuation: nil, newerThan: nil, unreadOnly: nil, log: support.log)
//		
//		let completionExpectation = expectation(description: "Did Finish")
//		getStreamContents.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(getStreamContents)
//		
//		waitForExpectations(timeout: 2)
//		
//		// verify entry providing and parsed item providing
//		guard let stream = getStreamContents.stream else {
//			return XCTFail("Expected to have stream.")
//		}
//		
//		let streamJSON = support.testJSON(named: jsonName) as! [String:Any]
//		
//		let id = streamJSON["id"] as! String
//		XCTAssertEqual(stream.id, id)
//		
//		let milliseconds = streamJSON["updated"] as! Double
//		let updated = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
//		XCTAssertEqual(stream.updated, updated)
//		
//		let continuation = streamJSON["continuation"] as! String
//		XCTAssertEqual(stream.continuation, continuation)
//		
//		support.check(getStreamContents.entries, correspondToStreamItemsIn: streamJSON)
//		support.check(stream.items, correspondToStreamItemsIn: streamJSON)
//	}
//}
