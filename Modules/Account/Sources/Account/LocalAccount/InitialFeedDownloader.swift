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

struct InitialFeedDownloaderResponse {
	let parsedFeed: ParsedFeed?
	let data: Data?
	let response: URLResponse?
}

struct InitialFeedDownloader {

	@MainActor static func download(_ url: URL) async throws -> InitialFeedDownloaderResponse {
		try await withCheckedThrowingContinuation { continuation in
			download(url) { (parsedFeed, data, response, error) in
				if let error {
					continuation.resume(throwing: error)
				} else {
					let response = InitialFeedDownloaderResponse(parsedFeed: parsedFeed, data: data, response: response)
					continuation.resume(returning: response)
				}
			}
		}
	}

	static func download(_ url: URL,_ completion: @escaping (_ parsedFeed: ParsedFeed?, _ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void) {
		Task { @MainActor in
			Downloader.shared.download(url) { (data, response, error) in
				guard let data = data else {
					completion(nil, nil, response, error)
					return
				}

				let parserData = ParserData(url: url.absoluteString, data: data)
				FeedParser.parse(parserData) { (parsedFeed, error) in
					completion(parsedFeed, data, response, error)
				}
			}
		}
	}
}
