//
//  HTMLMetadataDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Web
import Parser

struct HTMLMetadataDownloader {

	@MainActor static func downloadMetadata(for url: String) async -> HTMLMetadata? {

		guard let actualURL = URL(string: url) else {
			return nil
		}

		let downloadRecord = try? await DownloadWithCacheManager.shared.download(actualURL)
		let data = downloadRecord?.data
		let response = downloadRecord?.response

		if let data, !data.isEmpty, let response, response.statusIsOK {
			let urlToUse = response.url ?? actualURL
			let parserData = ParserData(url: urlToUse.absoluteString, data: data)
			return await parseMetadata(with: parserData)
		}

		return nil
	}

	@MainActor private static func parseMetadata(with parserData: ParserData) async -> HTMLMetadata? {

		let task = Task.detached { () -> HTMLMetadata? in
			HTMLMetadataParser.metadata(with: parserData)
		}

		return await task.value
	}
}
