//
//  HTMLMetadata+Extension.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
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

		// TODO: metadata icons — sometimes they’re large enough to use here.

		if let appleTouchIcon = largestAppleTouchIcon() {
			return appleTouchIcon
		}
		
		if let openGraphImageURL = openGraphProperties?.image {
			return openGraphImageURL.url
		}

		return twitterProperties?.imageURL
	}

	func bestFeaturedImageURL() -> String? {

		if let openGraphImageURL = openGraphProperties?.image {
			return openGraphImageURL.url
		}

		return twitterProperties?.imageURL
	}
}
