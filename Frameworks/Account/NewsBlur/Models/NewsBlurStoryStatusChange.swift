//
//  NewsBlurStoryStatusChange.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-13.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct NewsBlurStoryStatusChange {
	let hashes: [String]
}

extension NewsBlurStoryStatusChange: NewsBlurDataConvertible {
	var asData: Data? {
		var postData = URLComponents()
		postData.queryItems = hashes.map { URLQueryItem(name: "story_hash", value: $0) }

		return postData.percentEncodedQuery?.data(using: .utf8)
	}
}
