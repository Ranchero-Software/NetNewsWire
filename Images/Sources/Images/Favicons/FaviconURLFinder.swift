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
import ParserObjC
import UniformTypeIdentifiers

// The favicon URLs may be specified in the head section of the home page.

@MainActor struct FaviconURLFinder {

	/// Uniform types to ignore when finding favicon URLs.
	static let ignoredTypes = [UTType.svg]

	/// Finds favicon URLs in a web page.
	/// - Parameters:
	///   - homePageURL: The page to search.
	///   - urls: An array of favicon URLs as strings.
	static func findFaviconURLs(with homePageURL: String, downloadMetadata: ((String) async throws -> RSHTMLMetadata?)) async -> [String]? {

		guard let _ = URL(string: homePageURL) else {
			return nil
		}

		// If the favicon has an explicit type, check that for an ignored type; otherwise, check the file extension.
		let htmlMetadata = try? await downloadMetadata(homePageURL)

		let faviconURLs = htmlMetadata?.favicons.compactMap { favicon -> String? in
			shouldAllowFavicon(favicon) ? favicon.urlString : nil
		}

		return faviconURLs
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

