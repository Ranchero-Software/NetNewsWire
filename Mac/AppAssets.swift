//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Core
import Account
import Images

extension AppAsset {

	struct Mac {

		struct Timeline {
			static let swipeMarkRead = NSImage(systemSymbolName: "circle", accessibilityDescription: "Mark Read")!
				.withSymbolConfiguration(.init(scale: .large))
			static let swipeMarkUnread = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: "Mark Unread")!
				.withSymbolConfiguration(.init(scale: .large))
			static let swipeMarkStarred = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")!
				.withSymbolConfiguration(.init(scale: .large))
			static let swipeMarkUnstarred = NSImage(systemSymbolName: "star", accessibilityDescription: "Unstar")!
				.withSymbolConfiguration(.init(scale: .large))!
			static let starSelected = RSImage.appImage("timelineStar").tinted(with: .white)
			static let starUnselected = RSImage.appImage("timelineStar").tinted(with: AppAsset.starColor)
			static let separatorColor = NSColor(named: "timelineSeparatorColor")!
		}
	}
}


struct AppAssets {

	@MainActor
	static let searchFeedImage: IconImage = {
		return IconImage(NSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSupressed: true)
	}()
	
	static let starClosedImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!

	static let starOpenImage = NSImage(systemSymbolName: "star", accessibilityDescription: nil)!

	@MainActor
	static let starredFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
		let preferredColor = AppAsset.starColor
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	@MainActor
	static let todayFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)!
		let preferredColor = NSColor.orange
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	@MainActor
	static let unreadFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "AccentColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()
}
