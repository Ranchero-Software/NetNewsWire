//
//  TestGetStreamContentsService.swift
//  AccountTests
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//final class TestGetStreamContentsService: FeedlyGetStreamContentsService {
//	
//	var mockResult: Result<FeedlyStream, Error>?
//	var parameterTester: ((FeedlyResourceID, String?, Date?, Bool?) -> ())?
//	var getStreamContentsExpectation: XCTestExpectation?
//	
//	func getStreamContents(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?, completion: @escaping (Result<FeedlyStream, Error>) -> ()) {
//		guard let result = mockResult else {
//			XCTFail("Missing mock result. Test may time out because the completion will not be called.")
//			return
//		}
//		parameterTester?(resource, continuation, newerThan, unreadOnly)
//		DispatchQueue.main.async {
//			completion(result)
//			self.getStreamContentsExpectation?.fulfill()
//		}
//	}
//	
//	func makeMockFeedlyEntryItem() -> [FeedlyEntry] {
//		let origin = FeedlyOrigin(title: "XCTest@localhost", streamId: "user/12345/category/67890", htmlUrl: "http://localhost/nnw/xctest")
//		let content = FeedlyEntry.Content(content: "In the beginning...", direction: .leftToRight)
//		let items = [FeedlyEntry(id: "feeds/0/article/0",
//								 title: "RSS Reader Ingests Man",
//								 content: content,
//								 summary: content,
//								 author: nil,
//								 crawled: Date(),
//								 recrawled: nil,
//								 origin: origin,
//								 canonical: nil,
//								 alternate: nil,
//								 unread: true,
//								 tags: nil,
//								 categories: nil,
//								 enclosure: nil)]
//		return items
//	}
//}
