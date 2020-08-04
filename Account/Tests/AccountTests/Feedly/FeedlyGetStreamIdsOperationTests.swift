//
//  FeedlyGetStreamIdsOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 23/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSCore

class FeedlyGetStreamIdsOperationTests: XCTestCase {
	
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
	
	func testGetStreamIdsFailure() {
		let service = TestGetStreamIdsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		
		let getStreamIds = FeedlyGetStreamIdsOperation(account: account, resource: resource, service: service, continuation: nil, newerThan: nil, unreadOnly: nil, log: support.log)
		
		service.mockResult = .failure(URLError(.fileDoesNotExist))
		
		let completionExpectation = expectation(description: "Did Finish")
		getStreamIds.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(getStreamIds)
		
		waitForExpectations(timeout: 2)
		
		XCTAssertNil(getStreamIds.streamIds)
	}
	
	func testValuesPassingForGetStreamIds() {
		let service = TestGetStreamIdsService()
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		
		let continuation: String? = "gfdsa"
		let newerThan: Date? = Date(timeIntervalSinceReferenceDate: 1000)
		let unreadOnly: Bool? = false
		
		let getStreamIds = FeedlyGetStreamIdsOperation(account: account, resource: resource, service: service, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly, log: support.log)
		
		let mockStreamIds = FeedlyStreamIds(continuation: "1234", ids: ["item/1", "item/2", "item/3"])
		service.mockResult = .success(mockStreamIds)
		service.getStreamIdsExpectation = expectation(description: "Did Call Service")
		service.parameterTester = { serviceResource, serviceContinuation, serviceNewerThan, serviceUnreadOnly in
			// Verify these values given to the opeartion are passed to the service.
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertEqual(serviceContinuation, continuation)
			XCTAssertEqual(serviceNewerThan, newerThan)
			XCTAssertEqual(serviceUnreadOnly, unreadOnly)
		}
		
		let completionExpectation = expectation(description: "Did Finish")
		getStreamIds.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(getStreamIds)
		
		waitForExpectations(timeout: 2)
		
		guard let streamIds = getStreamIds.streamIds else {
			XCTFail("\(FeedlyGetStreamIdsOperation.self) did not store the stream.")
			return
		}
		
		XCTAssertEqual(streamIds.continuation, mockStreamIds.continuation)
		XCTAssertEqual(streamIds.ids, mockStreamIds.ids)
	}
	
	func testGetStreamIdsFromJSON() {
		let support = FeedlyTestSupport()
		let (transport, caller) = support.makeMockNetworkStack()
		let jsonName = "JSON/feedly_unreads_1000"
		transport.testFiles["/v3/streams/ids"] = "\(jsonName).json"
		
		let resource = FeedlyCategoryResourceId(id: "user/1234/category/5678")
		let getStreamIds = FeedlyGetStreamIdsOperation(account: account, resource: resource, service: caller, continuation: nil, newerThan: nil, unreadOnly: nil, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		getStreamIds.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(getStreamIds)
		
		waitForExpectations(timeout: 2)
		
		guard let streamIds = getStreamIds.streamIds else {
			return XCTFail("Expected to have a stream of identifiers.")
		}
		
		let streamIdsJSON = support.testJSON(named: jsonName) as! [String:Any]
				
		let continuation = streamIdsJSON["continuation"] as! String
		XCTAssertEqual(streamIds.continuation, continuation)
		XCTAssertEqual(streamIds.ids, streamIdsJSON["ids"] as! [String])
	}
}
