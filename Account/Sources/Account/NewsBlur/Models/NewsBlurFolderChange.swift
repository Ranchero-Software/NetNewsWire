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
	case rename(String, String)
	case delete(String, [String])
}

extension NewsBlurFolderChange: NewsBlurDataConvertible {
	var asData: Data? {
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

		// `+` is a valid character in query component as per RFC 3986 (https://developer.apple.com/documentation/foundation/nsurlcomponents/1407752-queryitems)
		// workaround:
		// - http://www.openradar.me/24076063
		// - https://stackoverflow.com/a/37314144
		return postData.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").replacingOccurrences(of: "%20", with: "+").data(using: .utf8)
	}
}
