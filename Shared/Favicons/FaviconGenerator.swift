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

@MainActor final class FaviconGenerator {
	static let shared = FaviconGenerator()

	private var cache = [String: IconImage]() // feedURL: IconImage

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		cache.removeAll()
	}

	func favicon(_ feed: Feed) -> IconImage {
		if let favicon = cache[feed.url] {
			return favicon
		}

		let colorHash = ColorHash(feed.url)
		if let favicon = Assets.Images.faviconTemplate.maskWithColor(color: colorHash.color.cgColor) {
			let iconImage = IconImage(favicon, isBackgroundSuppressed: true)
			cache[feed.url] = iconImage
			return iconImage
		} else {
			return IconImage(Assets.Images.faviconTemplate, isBackgroundSuppressed: true)
		}
	}
}
