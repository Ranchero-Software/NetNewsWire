//
//  FeedTitleDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/3/16.
//  Copyright © 2016 Ranchero Software. All rights reserved.
//

import Foundation
import RSXML
import RSWeb

func downloadTitleForFeed(_ url: URL, _ completionHandler: @escaping (_ title: String?) -> ()) {

	download(url) { (data, response, error) in

		guard let data = data else {
			completionHandler(nil)
			return
		}

		let xmlData = RSXMLData(data: data, urlString: url.absoluteString)
		RSParseFeed(xmlData) { (parsedFeed : RSParsedFeed?, error: Error?) in

			completionHandler(parsedFeed?.title)
		}
	}
}
