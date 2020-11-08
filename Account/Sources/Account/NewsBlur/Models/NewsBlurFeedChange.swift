//
//  NewsBlurFeedChange.swift
//  Account
//
//  Created by Anh Quang Do on 2020-03-14.
//  Copyright (c) 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

enum NewsBlurFeedChange {
	case add(String, String?)
	case rename(String, String)
	case delete(String, String?)
	case move(String, String?, String?)
}

extension NewsBlurFeedChange: NewsBlurDataConvertible {
	var asData: Data? {
		var postData = URLComponents()
		postData.queryItems = {
			switch self {
			case .add(let url, let folder):
				return [
					URLQueryItem(name: "url", value: url),
					folder != nil ? URLQueryItem(name: "folder", value: folder) : nil
				].compactMap { $0 }
			case .rename(let feedID, let newName):
				return [
					URLQueryItem(name: "feed_id", value: feedID),
					URLQueryItem(name: "feed_title", value: newName),
				]
			case .delete(let feedID, let folder):
				return [
					URLQueryItem(name: "feed_id", value: feedID),
					folder != nil ? URLQueryItem(name: "in_folder", value: folder) : nil,
				].compactMap { $0 }
			case .move(let feedID, let from, let to):
				return [
					URLQueryItem(name: "feed_id", value: feedID),
					URLQueryItem(name: "in_folder", value: from ?? ""),
					URLQueryItem(name: "to_folder", value: to ?? ""),
				]
			}
		}()

		// `+` is a valid character in query component as per RFC 3986 (https://developer.apple.com/documentation/foundation/nsurlcomponents/1407752-queryitems)
		// workaround:
		// - http://www.openradar.me/24076063
		// - https://stackoverflow.com/a/37314144
		return postData.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").replacingOccurrences(of: "%20", with: "+").data(using: .utf8)
	}
}
