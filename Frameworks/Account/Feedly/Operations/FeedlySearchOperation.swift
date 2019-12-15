//
//  FeedlySearchOperation.swift
//  Account
//
//  Created by Kiel Gillard on 1/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

protocol FeedlySearchService: class {
	func getFeeds(for query: String, count: Int, locale: String, completion: @escaping (Result<FeedlyFeedsSearchResponse, Error>) -> ())
}

protocol FeedlySearchOperationDelegate: class {
	func feedlySearchOperation(_ operation: FeedlySearchOperation, didGet response: FeedlyFeedsSearchResponse)
}

/// Single responsibility is to find one and only one feed for a given query (usually, a URL).
/// What happens when a feed is found for the URL is delegated to the `searchDelegate`.
class FeedlySearchOperation: FeedlyOperation {
	let query: String
	let locale: Locale
	let searchService: FeedlySearchService
	
	weak var searchDelegate: FeedlySearchOperationDelegate?
	
	init(query: String, locale: Locale = .current, service: FeedlySearchService) {
		self.query = query
		self.locale = locale
		self.searchService = service
	}
	
	override func main() {
		guard !isCancelled else {
			didFinish()
			return
		}
		
		searchService.getFeeds(for: query, count: 1, locale: locale.identifier) { result in
			switch result {
			case .success(let response):
				assert(Thread.isMainThread)
				self.searchDelegate?.feedlySearchOperation(self, didGet: response)
				self.didFinish()
				
			case .failure(let error):
				self.didFinish(error)
			}
		}
	}
}
