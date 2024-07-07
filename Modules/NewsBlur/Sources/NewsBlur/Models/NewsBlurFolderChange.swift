//
//  NewsBlurFolderChange.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-14.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public enum NewsBlurFolderChange: Sendable {

	case add(String)
	case rename(String, String)
	case delete(String, [String])
}

extension NewsBlurFolderChange: NewsBlurDataConvertible {
	
	public var asData: Data? {
		var postData = URLComponents()
		postData.queryItems = {
			switch self {
			case .add(let name):
				return [
					URLQueryItem(name: "folder", value: name),
					URLQueryItem(name: "parent_folder", value: ""), // root folder
				]
			case .rename(let from, let to):
				return [
					URLQueryItem(name: "folder_to_rename", value: from),
					URLQueryItem(name: "new_folder_name", value: to),
					URLQueryItem(name: "in_folder", value: ""), // root folder
				]
			case .delete(let name, let feedIDs):
				var queryItems = [
					URLQueryItem(name: "folder_to_delete", value: name),
					URLQueryItem(name: "in_folder", value: ""), // root folder
				]
				queryItems.append(contentsOf: feedIDs.map { id in
					URLQueryItem(name: "feed_id", value: id)
				})
				return queryItems
			}
		}()

		return postData.enhancedPercentEncodedQuery?.data(using: .utf8)
	}
}
