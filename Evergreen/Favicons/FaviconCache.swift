//
//  FaviconCache.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

final class FaviconCache {

	static var cache = [String: Favicon]()

	class func cachedFavicon(_ homePageURL: String) -> Favicon? {
		
		return cache[homePageURL]
	}

	class func cacheFavicon(_ homePageURL: String, _ favicon: Favicon) {

		cache[homePageURL] = favicon
	}

	class func removeFavicon(_ homePageURL: String) {

		cache[homePageURL] = nil
	}
}
