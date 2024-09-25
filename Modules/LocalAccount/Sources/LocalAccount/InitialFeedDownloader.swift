//
//  InitialFeedDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/3/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Parser
import Web

public struct InitialFeedDownloader {

	public static func download(_ url: URL) async -> ParsedFeed? {

		guard let downloadData = try? await DownloadWithCacheManager.shared.download(url) else {
			return nil
		}

		guard let data = downloadData.data else {
			return nil
		}

		guard let parsedFeed = try? FeedParser.parse(urlString: url.absoluteString, data: data) else {
			return nil
		}

		return parsedFeed
	}
}
