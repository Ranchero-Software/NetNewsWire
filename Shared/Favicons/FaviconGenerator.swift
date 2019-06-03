//
//  FaviconGenerator.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

final class FaviconGenerator {

	private static var faviconGeneratorCache = [String: RSImage]() // feedURL: RSImage

	static func favicon(_ feed: Feed) -> RSImage {
		
		if let favicon = FaviconGenerator.faviconGeneratorCache[feed.url] {
			return favicon
		}
		
		let colorHash = ColorHash(feed.url)
		if let favicon = AppAssets.faviconTemplateImage.maskWithColor(color: colorHash.color.cgColor) {
			FaviconGenerator.faviconGeneratorCache[feed.url] = favicon
			return favicon
		} else {
			return AppAssets.faviconTemplateImage
		}
		
	}
	
}
