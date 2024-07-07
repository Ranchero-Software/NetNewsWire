//
//  TestGetPagedStreamContentsService.swift
//  AccountTests
//
//  Created by Kiel Gillard on 28/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//final class TestGetPagedStreamContentsService: FeedlyGetStreamContentsService {
//	
//	var parameterTester: ((FeedlyResourceID, String?, Date?, Bool?) -> ())?
//	var getStreamContentsExpectation: XCTestExpectation?
//	var pages = [String: FeedlyStream]()
//	
//	func addAtLeastOnePage(for resource: FeedlyResourceID, continuations: [String], numberOfEntriesPerPage count: Int)  {
//		pages = [String: FeedlyStream](minimumCapacity: continuations.count + 1)
//		
//		// A continuation is an identifier for the next page.
//		// The first page has a nil identifier.
//		// The last page has no next page, so the next continuation value for that page is nil.
//		// Therefore, each page needs to know the identifier of the next page.
//		for index in -1..<continuations.count {
//			let nextIndex = index + 1
//			let continuation: String? = nextIndex < continuations.count ? continuations[nextIndex] : nil
//			let page = makeStreamContents(for: resource, continuation: continuation, between: 0..<count)
//			let key = TestGetPagedStreamContentsService.getPagingKey(for: resource, continuation: index < 0 ? nil : continuations[index])
//			pages[key] = page
//		}
//	}
//	
//	private func makeStreamContents(for resource: FeedlyResourceID, continuation: String?, between range: Range<Int>) -> FeedlyStream {
//		let entries = range.map { index -> FeedlyEntry in
//			let content = FeedlyEntry.Content(content: "Content \(index)",
//				direction: .leftToRight)
//			
//			let origin = FeedlyOrigin(title: "Origin \(index)",
//				streamId: resource.id,
//				htmlUrl: "http://localhost/feedly/origin/\(index)")
//			
//			return FeedlyEntry(id: "/articles/\(index)",
//				title: "Article \(index)",
//				content: content,
//				summary: content,
//				author: nil,
//				crawled: Date(),
//				recrawled: nil,
//				origin: origin,
//				canonical: nil,
//				alternate: nil,
//				unread: true,
//				tags: nil,
//				categories: nil,
//				enclosure: nil)
//		}
//		
//		let stream = FeedlyStream(id: resource.id, updated: nil, continuation: continuation, items: entries)
//		
//		return stream
//	}
//	
//	static func getPagingKey(for stream: FeedlyResourceID, continuation: String?) -> String {
//		return "\(stream.id)@\(continuation ?? "")"
//	}
//	
//	func getStreamContents(for resource: FeedlyResourceID, continuation: String?, newerThan: Date?, unreadOnly: Bool?, completion: @escaping (Result<FeedlyStream, Error>) -> ()) {
//		let key = TestGetPagedStreamContentsService.getPagingKey(for: resource, continuation: continuation)
//		guard let page = pages[key] else {
//			XCTFail("Missing page for \(resource.id) and continuation \(String(describing: continuation)). Test may time out because the completion will not be called.")
//			return
//		}
//		parameterTester?(resource, continuation, newerThan, unreadOnly)
//		DispatchQueue.main.async {
//			completion(.success(page))
//			self.getStreamContentsExpectation?.fulfill()
//		}
//	}
//}
