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
import RSCore

// The favicon URL may be specified in the head section of the home page.

struct FaviconURLFinder {

	static var metadataCache = [String: RSHTMLMetadata]()
	static let serialDispatchQueue = DispatchQueue(label: "FaviconURLFinder")

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
			faviconURL(urlToUse, data, callback)
		}
	}

	static private func faviconURL(_ url: String, _ webPageData: Data, _ callback: @escaping (String?) -> Void) {

		serialDispatchQueue.async {

			let md5String = (webPageData as NSData).rs_md5HashString()
			if let md5String = md5String, let cachedMetadata = metadataCache[md5String] {
				let cachedURL = cachedMetadata.faviconLink
				DispatchQueue.main.async {
					callback(cachedURL)
				}
				return
			}

			let parserData = ParserData(url: url, data: webPageData)
			let htmlMetadata = RSHTMLMetadataParser.htmlMetadata(with: parserData)
			if let md5String = md5String {
				metadataCache[md5String] = htmlMetadata
			}
			let url = htmlMetadata.faviconLink
			DispatchQueue.main.async {
				callback(url)
			}
		}
	}
}

