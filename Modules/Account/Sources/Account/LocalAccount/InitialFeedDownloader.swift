//
//  InitialFeedDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSParser
import RSWeb

struct InitialFeedDownloader {

	@MainActor static func download(_ url: URL) async throws -> (ParsedFeed?, URLResponse?) {
		let (data, response) = try await Downloader.shared.download(url)
		guard let data else {
			return (nil, response)
		}

		let parserData = ParserData(url: url.absoluteString, data: data)
		let parsedFeed = try await FeedParser.parse(parserData)
		return (parsedFeed, response)
	}
}
