//
//  FeedProvider.swift
//  FeedProvider
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import RSParser

public enum FeedProviderAbility {
	case owner
	case available
	case none
}

public protocol FeedProvider  {
	
	/// Informs the caller of the ability for this feed provider to service the given URL
	func ability(_ url: URLComponents, forUsername: String?) -> FeedProviderAbility
	
	/// Provide the iconURL of the given URL
	func iconURL(_ url: URLComponents, completion: @escaping (Result<String, Error>) -> Void)
	
	/// Construct a ParsedFeed that can be used to create and store a new Feed
	func provide(_ url: URLComponents, completion: @escaping (Result<ParsedFeed, Error>) -> Void)
	
	/// Refresh all the article entries (ParsedItems)
	func refresh(_ url: URLComponents, completion: @escaping (Result<Set<ParsedItem>, Error>) -> Void)
	
}
