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

		var bestImage: HTMLMetadataAppleTouchIcon?

		for image in icons {
			if let size = image.size {
				if size.width / size.height > 2 {
					continue
				}
			}
			if bestImage == nil {
				bestImage = image
				continue
			}
			if let size = image.size, let bestImageSize = bestImage!.size {
				if size.height > bestImageSize.height && size.width > bestImageSize.width {
					bestImage = image
				}
			}
		}

		return bestImage?.urlString
	}

	func bestWebsiteIconURL() -> String? {

		// TODO: metadata icons — sometimes they’re large enough to use here.

		if let appleTouchIcon = largestAppleTouchIcon() {
			return appleTouchIcon
		}

		if let openGraphImageURL = openGraphProperties?.image?.url {
			return openGraphImageURL
		}

		return twitterProperties?.imageURL
	}
}
