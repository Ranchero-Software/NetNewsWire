//
//  Dictionary+Web.swift
//  RSWeb
//
//  Created by Brent Simmons on 1/13/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

public extension Dictionary where Key == String, Value == String  {

	/// Translates a dictionary into a string like `foo=bar&param2=some%20thing`.
	var urlQueryString: String? {

		var queryItems = [URLQueryItem]()
		for (key, value) in self {
			queryItems.append(URLQueryItem(name: key, value: value))
		}

		var components = URLComponents()
		components.queryItems = queryItems
		let s = components.percentEncodedQuery

		return s == nil || s!.isEmpty ? nil : s
	}
}
