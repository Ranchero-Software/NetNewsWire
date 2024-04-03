//
//  FaviconURLFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/20/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import CoreServices
import Parser
import UniformTypeIdentifiers

// The favicon URLs may be specified in the head section of the home page.

struct FaviconURLFinder {

	/// Uniform types to ignore when finding favicon URLs.
	static var ignoredTypes = [UTType.svg]

	/// Finds favicon URLs in a web page.
	/// - Parameters:
	///   - homePageURL: The page to search.
	///   - completion: A closure called when the links have been found.
	///   - urls: An array of favicon URLs as strings.
	static func findFaviconURLs(with homePageURL: String, _ completion: @escaping (_ urls: [String]?) -> Void) {

		guard let _ = URL(unicodeString: homePageURL) else {
			completion(nil)
			return
		}

		// If the favicon has an explicit type, check that for an ignored type; otherwise, check the file extension.
		HTMLMetadataDownloader.downloadMetadata(for: homePageURL) { htmlMetadata in
			let faviconURLs = htmlMetadata?.favicons.compactMap { favicon -> String? in

				guard shouldAllowFavicon(favicon) else {
					return nil
				}
				return favicon.urlString
			}

			completion(faviconURLs)
		}
	}

	static func shouldAllowFavicon(_ favicon: RSHTMLMetadataFavicon) -> Bool {

		// Check mime type.
		if let mimeType = favicon.type, let utType = UTType(mimeType: mimeType) {
			if ignoredTypes.contains(utType) {
				return false
			}
		}

		// Check file extension.
		if let urlString = favicon.urlString, let url = URL(string: urlString), let utType = UTType(filenameExtension: url.pathExtension) {
			if ignoredTypes.contains(utType) {
				return false
			}
		}

		return true
	}
}

