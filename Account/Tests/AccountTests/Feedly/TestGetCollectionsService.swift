//
//  TestGetCollectionsService.swift
//  AccountTests
//
//  Created by Kiel Gillard on 30/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

//final class TestGetCollectionsService: FeedlyGetCollectionsService {
//	var mockResult: Result<[FeedlyCollection], Error>?
//	var getCollectionsExpectation: XCTestExpectation?
//	
//	func getCollections(completion: @escaping (Result<[FeedlyCollection], Error>) -> ()) {
//		guard let result = mockResult else {
//			XCTFail("Missing mock result. Test may time out because the completion will not be called.")
//			return
//		}
//		DispatchQueue.main.async {
//			completion(result)
//			self.getCollectionsExpectation?.fulfill()
//		}
//	}
//}
