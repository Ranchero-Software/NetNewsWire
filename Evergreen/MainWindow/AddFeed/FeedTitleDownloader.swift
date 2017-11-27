//
//  FeedTitleDownloader.swift
//  Evergreen
//
//  Created by Brent Simmons on 9/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSWeb

func downloadTitleForFeed(_ url: URL, _ completionHandler: @escaping (_ title: String?) -> ()) {

	downloadUsingCache(url) { (data, response, error) in

		guard let data = data else {
			completionHandler(nil)
			return
		}

		let parserData = ParserData(url: url.absoluteString, data: data)
		FeedParser.parse(parserData) { (parsedFeed, error) in
			completionHandler(parsedFeed?.title)
		}
	}
}
