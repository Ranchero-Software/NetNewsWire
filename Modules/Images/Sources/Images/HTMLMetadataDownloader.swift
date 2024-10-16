//
//  HTMLMetadataDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os
import Web
import Parser

public final class HTMLMetadataDownloader: Sendable {

	static let shared = HTMLMetadataDownloader()

	nonisolated(unsafe) private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HTMLMetadataDownloader")
	private let debugLoggingEnabled = false
	private let cache = HTMLMetadataCache()
	private let attemptDatesLock = OSAllocatedUnfairLock(initialState: [String: Date]())

	public func cachedMetadata(for url: String) -> HTMLMetadata? {

		if debugLoggingEnabled {
			Self.logger.debug("HTMLMetadataDownloader requested cached metadata for \(url)")
		}

		guard let htmlMetadata = cache[url] else {
			downloadMetadataIfNeeded(url)
			return nil
		}

		if debugLoggingEnabled {
			Self.logger.debug("HTMLMetadataDownloader returning cached metadata for \(url)")
		}
		return htmlMetadata
	}
}

private extension HTMLMetadataDownloader {

	private func downloadMetadataIfNeeded(_ url: String) {

		// We try a download once an hour at most.
		let shouldDownload = attemptDatesLock.withLock { attemptDates in

			let currentDate = Date()

			if let attemptDate = attemptDates[url], attemptDate > currentDate.bySubtracting(hours: 1) {
				if debugLoggingEnabled {
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

	private func downloadMetadata(_ url: String) {

		guard let actualURL = URL(string: url) else {
			if debugLoggingEnabled {
				Self.logger.debug("HTMLMetadataDownloader skipping download for \(url) because it couldn’t construct a URL.")
			}
			return
		}
		
		if debugLoggingEnabled {
			Self.logger.debug("HTMLMetadataDownloader downloading for \(url)")
		}

		Task {
			let downloadRecord = try? await DownloadWithCacheManager.shared.download(actualURL)
			let data = downloadRecord?.data
			let response = downloadRecord?.response

			if let data, !data.isEmpty, let response, response.statusIsOK {
				let urlToUse = response.url ?? actualURL
				let parserData = ParserData(url: urlToUse.absoluteString, data: data)
				let htmlMetadata = HTMLMetadataParser.metadata(with: parserData)
				if debugLoggingEnabled {
					Self.logger.debug("HTMLMetadataDownloader caching parsed metadata for \(url)")
				}
				cache[url] = htmlMetadata
				return
			}

			if debugLoggingEnabled {
				Self.logger.debug("HTMLMetadataDownloader failed download for \(url)")
			}
		}
	}
}
