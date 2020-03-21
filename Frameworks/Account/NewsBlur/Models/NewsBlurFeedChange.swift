//
//  NewsBlurFeedChange.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-14.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum NewsBlurFeedChange {
	case add(String)
}

extension NewsBlurFeedChange: NewsBlurDataConvertible {
	var asData: Data? {
		var postData = URLComponents()
		postData.queryItems = {
			switch self {
			case .add(let url):
				return [
					URLQueryItem(name: "url", value: url),
					URLQueryItem(name: "folder", value: ""), // root folder
				]
			}
		}()

		return postData.percentEncodedQuery?.data(using: .utf8)
	}
}
