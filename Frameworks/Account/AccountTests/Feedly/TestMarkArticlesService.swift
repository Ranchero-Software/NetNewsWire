//
//  TestMarkArticlesService.swift
//  AccountTests
//
//  Created by Kiel Gillard on 30/10/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import XCTest
@testable import Account

class TestMarkArticlesService: FeedlyMarkArticlesService {
	
	var didMarkExpectation: XCTestExpectation?
	var parameterTester: ((Set<String>, FeedlyMarkAction) -> ())?
	var mockResult: Result<Void, Error> = .success(())
	
	func mark(_ articleIds: Set<String>, as action: FeedlyMarkAction, completionHandler: @escaping (Result<Void, Error>) -> ()) {
		
		DispatchQueue.main.async {
			self.parameterTester?(articleIds, action)
			completionHandler(self.mockResult)
			self.didMarkExpectation?.fulfill()
		}
	}
}
