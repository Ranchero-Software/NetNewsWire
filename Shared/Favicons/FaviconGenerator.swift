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

	private static var faviconGeneratorCache = [String: IconImage]() // feedURL: RSImage

	static func favicon(_ webFeed: WebFeed) -> IconImage {
		
		if let favicon = FaviconGenerator.faviconGeneratorCache[webFeed.url] {
			return favicon
		}
		
		let colorHash = ColorHash(webFeed.url)
		if let favicon = AppAssets.faviconTemplateImage.maskWithColor(color: colorHash.color.cgColor) {
			let iconImage = IconImage(favicon)
			FaviconGenerator.faviconGeneratorCache[webFeed.url] = iconImage
			return iconImage
		} else {
			return IconImage(AppAssets.faviconTemplateImage)
		}
		
	}
	
}
