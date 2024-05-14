//
//  NewsBlurStoryStatusChange.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-13.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public struct NewsBlurStoryStatusChange: Sendable {

	public let hashes: Set<String>
}

extension NewsBlurStoryStatusChange: NewsBlurDataConvertible {
	
	public var asData: Data? {
		var postData = URLComponents()
		postData.queryItems = hashes.map { URLQueryItem(name: "story_hash", value: $0) }

		return postData.percentEncodedQuery?.data(using: .utf8)
	}
}
