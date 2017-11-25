//
//  FaviconURLFinder.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/20/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSParser
import RSWeb

// The favicon URL may be specified in the head section of the home page.

struct FaviconURLFinder {

	static func findFaviconURL(_ homePageURL: String, _ callback: @escaping (String?) -> Void) {

		guard let url = URL(string: homePageURL) else {
			callback(nil)
			return
		}

		downloadUsingCache(url) { (data, response, error) in

			guard let data = data, let response = response, response.statusIsOK else {
				callback(nil)
				return
			}

			// Use the absoluteString of the response’s URL instead of the homePageURL,
			// since the homePageURL might actually have been redirected.
			// Example: Dr. Drang’s feed reports the homePageURL as http://www.leancrew.com/all-this —
			// but it gets redirected to http://www.leancrew.com/all-this/ — which is correct.
			// This way any relative link to a favicon in the page’s metadata
			// will be made absolute correctly.

			let urlToUse = response.url?.absoluteString ?? homePageURL
			let link = faviconURL(urlToUse, data)
			callback(link)
		}
	}

	static private func faviconURL(_ url: String, _ webPageData: Data) -> String? {

		let parserData = ParserData(url: url, data: webPageData)
		let htmlMetadata = RSHTMLMetadataParser.htmlMetadata(with: parserData)
		return htmlMetadata.faviconLink
	}
}

