//
//  HTMLMetadataDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os
import RSParser

// To get a notification when HTMLMetadata is cached, see HTMLMetadataCache.

public final class HTMLMetadataDownloader: Sendable {

	public static let shared = HTMLMetadataDownloader()

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HTMLMetadataDownloader")
	private static let debugLoggingEnabled = false
	
	private let cache = HTMLMetadataCache()
	private let attemptDatesLock = OSAllocatedUnfairLock(initialState: [String: Date]())
	private let urlsReturning4xxsLock = OSAllocatedUnfairLock(initialState: Set<String>())

	public func cachedMetadata(for url: String) -> RSHTMLMetadata? {

		if Self.debugLoggingEnabled {
			Self.logger.debug("HTMLMetadataDownloader requested cached metadata for \(url)")
		}

		guard let htmlMetadata = cache[url] else {
			downloadMetadataIfNeeded(url)
			return nil
		}

		if Self.debugLoggingEnabled {
			Self.logger.debug("HTMLMetadataDownloader returning cached metadata for \(url)")
		}
		return htmlMetadata
	}
}

private extension HTMLMetadataDownloader {

	func downloadMetadataIfNeeded(_ url: String) {

		if urlShouldBeSkippedDueToPrevious4xxResponse(url) {
			if Self.debugLoggingEnabled {
				Self.logger.debug("HTMLMetadataDownloader skipping download for \(url) because an earlier request returned a 4xx response.")
			}
			return
		}

		// Limit how often a download should be attempted.
		let shouldDownload = attemptDatesLock.withLock { attemptDates in

			let currentDate = Date()

			let hoursBetweenAttempts = 3 // arbitrary
			if let attemptDate = attemptDates[url], attemptDate > currentDate.bySubtracting(hours: hoursBetweenAttempts) {
				if Self.debugLoggingEnabled {
					Self.logger.debug("HTMLMetadataDownloader skipping download for \(url) because an attempt was made less than an hour ago.")
				}
				return false
			}

			attemptDates[url] = currentDate
			return true
		}

		if shouldDownload {
			downloadMetadata(url)
		}
	}

	func downloadMetadata(_ url: String) {

		guard let actualURL = URL(string: url) else {
			if Self.debugLoggingEnabled {
				Self.logger.debug("HTMLMetadataDownloader skipping download for \(url) because it couldn’t construct a URL.")
			}
			return
		}

		if Self.debugLoggingEnabled {
			Self.logger.debug("HTMLMetadataDownloader downloading for \(url)")
		}

		Downloader.shared.download(actualURL) { data, response, error in
			if let data, !data.isEmpty, let response, response.statusIsOK {
				let urlToUse = response.url ?? actualURL
				let parserData = ParserData(url: urlToUse.absoluteString, data: data)
				let htmlMetadata = RSHTMLMetadataParser.htmlMetadata(with: parserData)
				if Self.debugLoggingEnabled {
					Self.logger.debug("HTMLMetadataDownloader caching parsed metadata for \(url)")
				}
				self.cache[url] = htmlMetadata
				return
			}

			if let statusCode = response?.forcedStatusCode, (400...499).contains(statusCode) {
				self.noteURLDidReturn4xx(url)
			}

			if Self.debugLoggingEnabled {
				Self.logger.debug("HTMLMetadataDownloader failed download for \(url)")
			}
		}
	}

	func urlShouldBeSkippedDueToPrevious4xxResponse(_ url: String) -> Bool {

		urlsReturning4xxsLock.withLock { $0.contains(url) }
	}

	func noteURLDidReturn4xx(_ url: String) {

		_ = urlsReturning4xxsLock.withLock { $0.insert(url) }
	}
}
