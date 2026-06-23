//
//  FaviconGenerator.swift
//  Images
//
//  Created by Maurice Parker on 4/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

@MainActor public final class FaviconGenerator {
	public static let shared = FaviconGenerator()

	/// The template image used to synthesize colored placeholders. The app must
	/// set this at launch (see Mac/iOS AppDelegate) before any feed is shown.
	public static var templateImage: RSImage?

	private var cache = [String: IconImage]() // feedURL: IconImage

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
	}

	@objc func handleLowMemory(_ notification: Notification) {
		cache.removeAll()
	}

	@objc func handleAppDidGoToBackground(_ notification: Notification) {
		cache.removeAll()
	}

	public func favicon(_ feed: Feed) -> IconImage {
		guard let template = Self.templateImage else {
			preconditionFailure("FaviconGenerator.templateImage must be set at app launch")
		}

		if let favicon = cache[feed.url] {
			return favicon
		}

		let colorHash = ColorHash(feed.url)
		if let favicon = template.maskWithColor(color: colorHash.color.cgColor) {
			let iconImage = IconImage(favicon, isBackgroundSuppressed: true)
			cache[feed.url] = iconImage
			return iconImage
		} else {
			return IconImage(template, isBackgroundSuppressed: true)
		}
	}
}
