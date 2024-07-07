//
//  TestGetEntriesService.swift
//  AccountTests
//
//  Created by Kiel Gillard on 11/1/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//final class TestGetEntriesService: FeedlyGetEntriesService {
//	var mockResult: Result<[FeedlyEntry], Error>?
//	var getEntriesExpectation: XCTestExpectation?
//	
//	func getEntries(for ids: Set<String>, completion: @escaping (Result<[FeedlyEntry], Error>) -> ()) {
//		guard let result = mockResult else {
//			XCTFail("Missing mock result. Test may time out because the completion will not be called.")
//			return
//		}
//		DispatchQueue.main.async {
//			completion(result)
//			self.getEntriesExpectation?.fulfill()
//		}
//	}
//}
