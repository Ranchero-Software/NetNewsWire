//
//  NSURL+RSWeb.swift
//  RSWeb
//
//  Created by Brent Simmons on 12/26/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
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
	
	func preparedForOpeningInBrowser() -> URL? {
		var urlString = absoluteString.replacingOccurrences(of: " ", with: "%20")
		urlString = urlString.replacingOccurrences(of: "^", with: "%5E")
		urlString = urlString.replacingOccurrences(of: "&amp;", with: "&")
		urlString = urlString.replacingOccurrences(of: "&#38;", with: "&")
		
		return URL(string: urlString)
	}
}
