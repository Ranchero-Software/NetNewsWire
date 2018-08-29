//
//  HTMLMetadataDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSWeb
import RSParser

struct HTMLMetadataDownloader {

	static var metadataCache = [String: RSHTMLMetadata]()
	static let serialDispatchQueue = DispatchQueue(label: "HTMLMetadataDownloader")

	static func downloadMetadata(for url: String, _ callback: @escaping (RSHTMLMetadata?) -> Void) {

		guard let actualURL = URL(string: url) else {
			callback(nil)
			return
		}

		downloadUsingCache(actualURL) { (data, response, error) in

			if let data = data, !data.isEmpty, let response = response, response.statusIsOK, error == nil {

				let urlToUse = response.url ?? actualURL
				let parserData = ParserData(url: urlToUse.absoluteString, data: data)
				parseMetadata(with: parserData, callback)
				return
			}

			if let error = error {
				appDelegate.logMessage("Error downloading metadata at \(url): \(error)", type: .warning)
			}

			callback(nil)
		}
	}

	private static func parseMetadata(with parserData: ParserData, _ callback: @escaping (RSHTMLMetadata?) -> Void) {

		serialDispatchQueue.async {

			let md5String = (parserData.data as NSData).rs_md5HashString()
			if let md5String = md5String, let cachedMetadata = metadataCache[md5String] {
				DispatchQueue.main.async {
					callback(cachedMetadata)
				}
				return
			}

			let htmlMetadata = RSHTMLMetadataParser.htmlMetadata(with: parserData)
			if let md5String = md5String {
				metadataCache[md5String] = htmlMetadata
			}

			DispatchQueue.main.async {
				callback(htmlMetadata)
			}
		}
	}
}
