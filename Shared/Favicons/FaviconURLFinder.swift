//
//  FaviconURLFinder.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/20/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import CoreServices
import RSParser
import UniformTypeIdentifiers

// The favicon URLs may be specified in the head section of the home page.

struct FaviconURLFinder {

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
		HTMLMetadataDownloader.downloadMetadata(for: homePageURL) { (htmlMetadata) in

			guard let favicons = htmlMetadata?.favicons else {
				completion(nil)
				return
			}

			let faviconURLs = favicons.compactMap {
				shouldAllowFavicon($0) ? $0.urlString : nil
			}

			completion(faviconURLs)
		}
	}

	private static let ignoredTypes = [UTType.svg]

	private static func shouldAllowFavicon(_ favicon: RSHTMLMetadataFavicon) -> Bool {

		// Check mime type.
		if let mimeType = favicon.type, let utType = UTType(mimeType: mimeType) {
			if Self.ignoredTypes.contains(utType) {
				return false
			}
		}

		// Check file extension.
		if let urlString = favicon.urlString, let url = URL(string: urlString), let utType = UTType(filenameExtension: url.pathExtension) {
			if Self.ignoredTypes.contains(utType) {
				return false
			}
		}

		return true
	}
}
