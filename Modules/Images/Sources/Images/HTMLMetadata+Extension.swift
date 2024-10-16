//
//  HTMLMetadata+Extension.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers
import Parser

extension HTMLMetadata {

	func largestAppleTouchIcon() -> String? {

		guard let icons = appleTouchIcons, !icons.isEmpty else {
			return nil
		}

		var bestImage: HTMLMetadataAppleTouchIcon? = nil

		for image in icons {

			guard let imageSize = image.size else {
				continue
			}
			if imageSize.width / imageSize.height > 2 {
				continue
			}

			guard let currentBestImage = bestImage, let bestImageSize = currentBestImage.size else {
				bestImage = image
				continue
			}

			if imageSize.height > bestImageSize.height && imageSize.width > bestImageSize.width {
				bestImage = image
			}
		}

		return bestImage?.urlString ?? icons.first?.urlString
	}

	func bestWebsiteIconURL() -> String? {

		largestAppleTouchIcon() ?? openGraphProperties?.image?.url ?? twitterProperties?.imageURL
	}

	func usableFaviconURLs() -> [String]? {

		favicons?.compactMap { favicon in
			shouldAllowFavicon(favicon) ? favicon.urlString : nil
		}
	}
}

private extension HTMLMetadata {

	static let ignoredTypes = [UTType.svg]

	private func shouldAllowFavicon(_ favicon: HTMLMetadataFavicon) -> Bool {

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
