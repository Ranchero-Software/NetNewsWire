//
//  TestGetPagedStreamIdsService.swift
//  AccountTests
//
//  Created by Kiel Gillard on 29/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

final class TestGetPagedStreamIdsService: FeedlyGetStreamIdsService {
	
	var parameterTester: ((FeedlyResourceId, String?, Date?, Bool?) -> ())?
	var getStreamIdsExpectation: XCTestExpectation?
	var pages = [String: FeedlyStreamIds]()
	
	func addAtLeastOnePage(for resource: FeedlyResourceId, continuations: [String], numberOfEntriesPerPage count: Int)  {
		pages = [String: FeedlyStreamIds](minimumCapacity: continuations.count + 1)
		
		// A continuation is an identifier for the next page.
		// The first page has a nil identifier.
		// The last page has no next page, so the next continuation value for that page is nil.
		// Therefore, each page needs to know the identifier of the next page.
		for index in -1..<continuations.count {
			let nextIndex = index + 1
			let continuation: String? = nextIndex < continuations.count ? continuations[nextIndex] : nil
			let page = makeStreamIds(for: resource, continuation: continuation, between: 0..<count)
			let key = TestGetPagedStreamIdsService.getPagingKey(for: resource, continuation: index < 0 ? nil : continuations[index])
			pages[key] = page
		}
	}
	
	private func makeStreamIds(for resource: FeedlyResourceId, continuation: String?, between range: Range<Int>) -> FeedlyStreamIds {
		let entryIds = range.map { _ in UUID().uuidString }
		let stream = FeedlyStreamIds(continuation: continuation, ids: entryIds)
		return stream
	}
	
	static func getPagingKey(for stream: FeedlyResourceId, continuation: String?) -> String {
		return "\(stream.id)@\(continuation ?? "")"
	}
	
	func getStreamIds(for resource: FeedlyResourceId, continuation: String?, newerThan: Date?, unreadOnly: Bool?, completion: @escaping (Result<FeedlyStreamIds, Error>) -> ()) {
		let key = TestGetPagedStreamIdsService.getPagingKey(for: resource, continuation: continuation)
		guard let page = pages[key] else {
			XCTFail("Missing page for \(resource.id) and continuation \(String(describing: continuation)). Test may time out because the completion will not be called.")
			return
		}
		parameterTester?(resource, continuation, newerThan, unreadOnly)
		DispatchQueue.main.async {
			completion(.success(page))
			self.getStreamIdsExpectation?.fulfill()
		}
	}
}
