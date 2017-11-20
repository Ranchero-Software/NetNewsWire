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

		download(url) { (data, response, error) in

			guard let data = data, let response = response, response.statusIsOK else {
				callback(nil)
				return
			}

			let link = faviconURL(homePageURL, data)
			callback(link)
		}
	}

	static private func faviconURL(_ url: String, _ webPageData: Data) -> String? {

		let parserData = ParserData(url: url, data: webPageData)
		let htmlMetadata = RSHTMLMetadataParser.htmlMetadata(with: parserData)
		return htmlMetadata.faviconLink
	}
}

