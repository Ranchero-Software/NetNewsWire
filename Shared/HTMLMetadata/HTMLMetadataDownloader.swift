//
//  HTMLMetadataDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSWeb
import Parser

struct HTMLMetadataDownloader {

	static let serialDispatchQueue = DispatchQueue(label: "HTMLMetadataDownloader")

	static func downloadMetadata(for url: String, _ completion: @escaping (HTMLMetadata?) -> Void) {
		guard let actualURL = URL(string: url) else {
			completion(nil)
			return
		}

		downloadUsingCache(actualURL) { (data, response, error) in
			if let data = data, !data.isEmpty, let response = response, response.statusIsOK, error == nil {
				let urlToUse = response.url ?? actualURL
				let parserData = ParserData(url: urlToUse.absoluteString, data: data)
				parseMetadata(with: parserData, completion)
				return
			}

			completion(nil)
		}
	}

	private static func parseMetadata(with parserData: ParserData, _ completion: @escaping (HTMLMetadata?) -> Void) {
		serialDispatchQueue.async {
			let htmlMetadata = HTMLMetadataParser.metadata(with: parserData)
			DispatchQueue.main.async {
				completion(htmlMetadata)
			}
		}
	}
}
