//
//  FeedlySearchOperation.swift
//  Account
//
//  Created by Kiel Gillard on 1/12/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol FeedlySearchService: AnyObject {
	
	@MainActor func getFeeds(for query: String, count: Int, localeIdentifier: String) async throws -> FeedlyFeedsSearchResponse
}

public protocol FeedlySearchOperationDelegate: AnyObject {

	@MainActor func feedlySearchOperation(_ operation: FeedlySearchOperation, didGet response: FeedlyFeedsSearchResponse)
}

/// Find one and only one feed for a given query (usually, a URL).
/// What happens when a feed is found for the URL is delegated to the `searchDelegate`.
public final class FeedlySearchOperation: FeedlyOperation {

	let query: String
	let locale: Locale
	let searchService: FeedlySearchService
	public weak var searchDelegate: FeedlySearchOperationDelegate?

	public init(query: String, locale: Locale = .current, service: FeedlySearchService) {
		self.query = query
		self.locale = locale
		self.searchService = service
	}
	
	public override func run() {

		Task { @MainActor in

			do {
				let searchResponse = try await searchService.getFeeds(for: query, count: 1, localeIdentifier: locale.identifier)
				self.searchDelegate?.feedlySearchOperation(self, didGet: searchResponse)
				self.didFinish()
				
			} catch {
				self.didFinish(with: error)
			}
		}
	}
}
