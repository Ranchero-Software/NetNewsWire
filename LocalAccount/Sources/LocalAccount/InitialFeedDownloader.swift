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

	@MainActor public static func download(_ url: URL) async -> ParsedFeed? {

		await withCheckedContinuation { @MainActor continuation in
			self.download(url) { parsedFeed in
				continuation.resume(returning: parsedFeed)
			}
		}
	}

	@MainActor public static func download(_ url: URL,_ completion: @escaping @Sendable (_ parsedFeed: ParsedFeed?) -> Void) {

		Task {

			guard let downloadData = try? await downloadUsingCache(url) else {
				completion(nil)
				return
			}
			guard let data = downloadData.data else {
				completion(nil)
				return
			}

			let parserData = ParserData(url: url.absoluteString, data: data)

			Task.detached {
				guard let parsedFeed = try? await FeedParser.parse(parserData) else {
					completion(nil)
					return
				}

				completion(parsedFeed)
			}
		}
	}
}
