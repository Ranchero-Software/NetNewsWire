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

	private static var ignoredMimeTypes = [String]()
	private static var ignoredExtensions = [String]()

	/// Uniform types to ignore when finding favicon URLs.
	static var ignoredTypes: [String]? {
		didSet {
			guard let ignoredTypes = ignoredTypes else {
				return
			}

			for type in ignoredTypes {
				if let mimeType = UTTypeReference(type)?.preferredMIMEType {
					ignoredMimeTypes.append(mimeType)
				}
				if let fileNameExtension = UTTypeReference(type)?.preferredFilenameExtension {
					ignoredExtensions.append(fileNameExtension)
				}
			}
		}
	}

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
			let faviconURLs = htmlMetadata?.favicons.compactMap({ (favicon) -> String? in
				if let type = favicon.type {
					if ignoredMimeTypes.contains(type) {
						return nil
					}
				}
				else {
					if let urlString = favicon.urlString, let url = URL(string: urlString), ignoredExtensions.contains(url.pathExtension) {
						return nil
					}
				}

				return favicon.urlString
			})

			completion(faviconURLs)
		}
	}
}

