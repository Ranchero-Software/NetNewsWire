//
//  RSHTMLMetadata+Extension.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import Parser
import ParserObjC

extension RSHTMLMetadata {

	func largestOpenGraphImageURL() -> String? {
		let openGraphImages = openGraphProperties.images

		guard !openGraphImages.isEmpty else {
			return nil
		}

		var bestImage: RSHTMLOpenGraphImage? = nil

		for image in openGraphImages {
			if image.width / image.height > 2 {
				continue
			}
			if bestImage == nil {
				bestImage = image
				continue
			}
			if image.height > bestImage!.height && image.width > bestImage!.width {
				bestImage = image
			}
		}

		guard let url = bestImage?.secureURL ?? bestImage?.url else {
			return nil
		}

		// Bad ones we should ignore.
		let badURLs = Set(["https://s0.wp.com/i/blank.jpg"])
		guard !badURLs.contains(url) else {
			return nil
		}

		return url
	}

	func largestAppleTouchIcon() -> String? {

		let icons = appleTouchIcons

		guard !icons.isEmpty else {
			return nil
		}

		var bestImage: RSHTMLMetadataAppleTouchIcon? = nil

		for image in icons {
			if image.size.width / image.size.height > 2 {
				continue
			}
			if bestImage == nil {
				bestImage = image
				continue
			}
			if image.size.height > bestImage!.size.height && image.size.width > bestImage!.size.width {
				bestImage = image;
			}
		}

		return bestImage?.urlString
	}

	func bestWebsiteIconURL() -> String? {

		// TODO: metadata icons — sometimes they’re large enough to use here.

		if let appleTouchIcon = largestAppleTouchIcon() {
			return appleTouchIcon
		}
		
		if let openGraphImageURL = largestOpenGraphImageURL() {
			return openGraphImageURL
		}

		return twitterProperties.imageURL
	}

	func bestFeaturedImageURL() -> String? {

		if let openGraphImageURL = largestOpenGraphImageURL() {
			return openGraphImageURL
		}

		return twitterProperties.imageURL
	}
}
