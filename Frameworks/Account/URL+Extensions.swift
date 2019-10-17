//
//  URL+Extensions.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-10-16.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation


public extension URL {
	
	func appendingQueryItem(_ queryItem: URLQueryItem) -> URL? {
		appendingQueryItems([queryItem])
	}

	func appendingQueryItems(_ queryItems: [URLQueryItem]) -> URL? {
		guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
			return nil
		}
		
		var newQueryItems = components.queryItems ?? []
		newQueryItems.append(contentsOf: queryItems)
		components.queryItems = newQueryItems
		
		return components.url
	}
	
}
