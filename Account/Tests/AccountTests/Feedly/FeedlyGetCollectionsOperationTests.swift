//
//  FeedlyGetCollectionsOperationTests.swift
//  AccountTests
//
//  Created by Kiel Gillard on 21/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account
import os.log

//class FeedlyGetCollectionsOperationTests: XCTestCase {
//		
//	func testGetCollections() {
//		let support = FeedlyTestSupport()
//		let (transport, caller) = support.makeMockNetworkStack()
//		let jsonName = "JSON/feedly_collections_initial"
//		transport.testFiles["/v3/collections"] = "\(jsonName).json"
//		
//		let getCollections = FeedlyGetCollectionsOperation(service: caller, log: support.log)
//		let completionExpectation = expectation(description: "Did Finish")
//		getCollections.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(getCollections)
//		
//		waitForExpectations(timeout: 2)
//		
//		let collections = support.testJSON(named: jsonName) as! [[String:Any]]
//		let labelsInJSON = Set(collections.map { $0["label"] as! String })
//		let idsInJSON = Set(collections.map { $0["id"] as! String })
//		
//		let labels = Set(getCollections.collections.map { $0.label })
//		let ids = Set(getCollections.collections.map { $0.id })
//		
//		let missingLabels = labelsInJSON.subtracting(labels)
//		let missingIDs = idsInJSON.subtracting(ids)
//
//		XCTAssertEqual(getCollections.collections.count, collections.count, "Mismatch between collections provided by operation and test JSON collections.")
//		XCTAssertTrue(missingLabels.isEmpty, "Collections with these labels did not have a corresponding \(FeedlyCollection.self) value with the same name.")
//		XCTAssertTrue(missingIDs.isEmpty, "Collections with these ids did not have a corresponding \(FeedlyCollection.self) with the same id.")
//		
//		for collection in collections {
//			let collectionID = collection["id"] as! String
//			let collectionFeeds = collection["feeds"] as! [[String: Any]]
//			let collectionFeedIDs = Set(collectionFeeds.map { $0["id"] as! String })
//
//			for operationCollection in getCollections.collections where operationCollection.id == collectionID {
//				let feedIDs = Set(operationCollection.feeds.map { $0.id })
//				let missingIDs = collectionFeedIDs.subtracting(feedIDs)
//				XCTAssertTrue(missingIDs.isEmpty, "Feeds with these ids were not found in the \"\(operationCollection.label)\" \(FeedlyCollection.self).")
//			}
//		}
//	}
//	
//	func testGetCollectionsError() {
//		
//		class TestDelegate: FeedlyOperationDelegate {
//			var errorExpectation: XCTestExpectation?
//			var error: Error?
//			
//			func feedlyOperation(_ operation: FeedlyOperation, didFailWith error: Error) {
//				self.error = error
//				errorExpectation?.fulfill()
//			}
//		}
//		
//		let delegate = TestDelegate()
//		delegate.errorExpectation = expectation(description: "Did Fail With Expected Error")
//		
//		let support = FeedlyTestSupport()
//		let service = TestGetCollectionsService()
//		service.mockResult = .failure(URLError(.timedOut))
//		
//		let getCollections = FeedlyGetCollectionsOperation(service: service, log: support.log)
//		getCollections.delegate = delegate
//		
//		let completionExpectation = expectation(description: "Did Finish")
//		getCollections.completionBlock = { _ in
//			completionExpectation.fulfill()
//		}
//		
//		MainThreadOperationQueue.shared.add(getCollections)
//		
//		waitForExpectations(timeout: 2)
//		
//		XCTAssertNotNil(delegate.error)
//		XCTAssertTrue(getCollections.collections.isEmpty, "Collections should be empty.")
//	}
//}
