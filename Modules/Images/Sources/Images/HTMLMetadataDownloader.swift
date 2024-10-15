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

struct HTMLMetadataDownloader {

	nonisolated(unsafe) private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "HTMLMetadataDownloader")
	private static let debugLoggingEnabled = true

	static func downloadMetadata(for url: String) async -> HTMLMetadata? {

		if debugLoggingEnabled {
			logger.debug("HTMLMetadataDownloader download for \(url)")
		}

		guard let actualURL = URL(string: url) else {
			return nil
		}

		let downloadRecord = try? await DownloadWithCacheManager.shared.download(actualURL)
		let data = downloadRecord?.data
		let response = downloadRecord?.response

		if let data, !data.isEmpty, let response, response.statusIsOK {
			let urlToUse = response.url ?? actualURL
			let parserData = ParserData(url: urlToUse.absoluteString, data: data)

			if debugLoggingEnabled {
				logger.debug("HTMLMetadataDownloader parsing metadata for \(url)")
			}

			return await parseMetadata(with: parserData)
		}

		if debugLoggingEnabled {
			logger.debug("HTMLMetadataDownloader failed download for \(url)")
		}

		return nil
	}

	private static func parseMetadata(with parserData: ParserData) async -> HTMLMetadata? {

		return HTMLMetadataParser.metadata(with: parserData)
	}
}
