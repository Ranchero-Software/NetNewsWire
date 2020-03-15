//
//  NewsBlurFolderChange.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-14.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum NewsBlurFolderChange {
	case add(String)
}

extension NewsBlurFolderChange {
	var asData: Data? {
		var postData = URLComponents()
		postData.queryItems = {
			switch self {
			case .add(let name):
				return [URLQueryItem(name: "folder", value: name)]
			}
		}()

		return postData.percentEncodedQuery?.data(using: .utf8)
	}
}
