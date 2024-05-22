//
//  TestGetPagedStreadIDsService.swift
//  AccountTests
//
//  Created by Kiel Gillard on 29/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//final class TestGetPagedStreadIDsService: FeedlyGetStreamIDsService {
//	
//	var parameterTester: ((FeedlyResourceID, String?, Date?, Bool?) -> ())?
//	var getStreadIDsExpectation: XCTestExpectation?
//	var pages = [String: FeedlyStreamIDs]()
//	
//	func addAtLeastOnePage(for resource: FeedlyResourceID, continuations: [String], numberOfEntriesPerPage count: Int)  {
//		pages = [String: FeedlyStreamIDs](minimumCapacity: continuations.count + 1)
//		
//		// A continuation is an identifier for the next page.
//		// The first page has a nil identifier.
//		// The last page has no next page, so the next continuation value for that page is nil.
//		// Therefore, each page needs to know the identifier of the next page.
//		for index in -1..<continuations.count {
//			let nextIndex = index + 1
//			let continuation: String? = nextIndex < continuations.count ? continuations[nextIndex] : nil
//			let page = makeStreadIDs(for: resource, continuation: continuation, between: 0..<count)
//			let key = TestGetPagedStreadIDsService.getPagingKey(for: resource, continuation: index < 0 ? nil : continuations[index])
//			pages[key] = page
//		}
//	}
//	
//	private func makeStreadIDs(for resource: FeedlyResourceID, continuation: String?, between range: Range<Int>) -> FeedlyStreamIDs {
//		let entryIDs = range.map { _ in UUID().uuidString }
//		let stream = FeedlyStreamIDs(continuation: continuation, ids: entryIDs)
//		return stream
//	}
//	
//	static func getPagingKey(for stream: FeedlyResourceID, continuation: String?) -> String {
//		return "\(stream.id)@\(continuation ?? "")"
//	}
//	
//	func getStreamIDs(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?, completion: @escaping (Result<FeedlyStreamIDs, Error>) -> ()) {
//		let key = TestGetPagedStreadIDsService.getPagingKey(for: resource, continuation: continuation)
//		guard let page = pages[key] else {
//			XCTFail("Missing page for \(resource.id) and continuation \(String(describing: continuation)). Test may time out because the completion will not be called.")
//			return
//		}
//		parameterTester?(resource, continuation, newerThan, unreadOnly)
//		DispatchQueue.main.async {
//			completion(.success(page))
//			self.getStreadIDsExpectation?.fulfill()
//		}
//	}
//}
