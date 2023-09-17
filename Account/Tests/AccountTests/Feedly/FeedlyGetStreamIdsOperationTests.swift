//
//  FeedlyGetStreamIDsOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 23/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import RSCore

class FeedlyGetStreamIDsOperationTests: XCTestCase {
	
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
	
	func testGetStreamIDsFailure() {
		let service = TestGetStreamIDsService()
		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
		
		let getStreamIDs = FeedlyGetStreamIDsOperation(account: account, resource: resource, service: service, continuation: nil, newerThan: nil, unreadOnly: nil, log: support.log)
		
		service.mockResult = .failure(URLError(.fileDoesNotExist))
		
		let completionExpectation = expectation(description: "Did Finish")
		getStreamIDs.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(getStreamIDs)
		
		waitForExpectations(timeout: 2)
		
		XCTAssertNil(getStreamIDs.streamIDs)
	}
	
	func testValuesPassingForGetStreamIDs() {
		let service = TestGetStreamIDsService()
		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
		
		let continuation: String? = "gfdsa"
		let newerThan: Date? = Date(timeIntervalSinceReferenceDate: 1000)
		let unreadOnly: Bool? = false
		
		let getStreamIDs = FeedlyGetStreamIDsOperation(account: account, resource: resource, service: service, continuation: continuation, newerThan: newerThan, unreadOnly: unreadOnly, log: support.log)
		
		let mockStreamIDs = FeedlyStreamIDs(continuation: "1234", ids: ["item/1", "item/2", "item/3"])
		service.mockResult = .success(mockStreamIDs)
		service.getStreamIDsExpectation = expectation(description: "Did Call Service")
		service.parameterTester = { serviceResource, serviceContinuation, serviceNewerThan, serviceUnreadOnly in
			// Verify these values given to the operation are passed to the service.
			XCTAssertEqual(serviceResource.id, resource.id)
			XCTAssertEqual(serviceContinuation, continuation)
			XCTAssertEqual(serviceNewerThan, newerThan)
			XCTAssertEqual(serviceUnreadOnly, unreadOnly)
		}
		
		let completionExpectation = expectation(description: "Did Finish")
		getStreamIDs.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(getStreamIDs)
		
		waitForExpectations(timeout: 2)
		
		guard let streamIDs = getStreamIDs.streamIDs else {
			XCTFail("\(FeedlyGetStreamIDsOperation.self) did not store the stream.")
			return
		}
		
		XCTAssertEqual(streamIDs.continuation, mockStreamIDs.continuation)
		XCTAssertEqual(streamIDs.ids, mockStreamIDs.ids)
	}
	
	func testGetStreamIDsFromJSON() {
		let support = FeedlyTestSupport()
		let (transport, caller) = support.makeMockNetworkStack()
		let jsonName = "JSON/feedly_unreads_1000"
		transport.testFiles["/v3/streams/ids"] = "\(jsonName).json"
		
		let resource = FeedlyCategoryResourceID(id: "user/1234/category/5678")
		let getStreamIDs = FeedlyGetStreamIDsOperation(account: account, resource: resource, service: caller, continuation: nil, newerThan: nil, unreadOnly: nil, log: support.log)
		
		let completionExpectation = expectation(description: "Did Finish")
		getStreamIDs.completionBlock = { _ in
			completionExpectation.fulfill()
		}
		
		MainThreadOperationQueue.shared.add(getStreamIDs)
		
		waitForExpectations(timeout: 2)
		
		guard let streamIDs = getStreamIDs.streamIDs else {
			return XCTFail("Expected to have a stream of identifiers.")
		}
		
		let streamIDsJSON = support.testJSON(named: jsonName) as! [String:Any]
				
		let continuation = streamIDsJSON["continuation"] as! String
		XCTAssertEqual(streamIDs.continuation, continuation)
		XCTAssertEqual(streamIDs.ids, streamIDsJSON["ids"] as! [String])
	}
}
