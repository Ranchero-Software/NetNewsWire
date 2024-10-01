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

		static let iconLightBackgroundColor = NSColor(named: "iconLightBackgroundColor")!
		static let iconDarkBackgroundColor = NSColor(named: "iconDarkBackgroundColor")!

		static let marsEditIcon = RSImage.appImage("MarsEditIcon")
		static let microblogIcon = RSImage.appImage("MicroblogIcon")

		struct Toolbar {
			static let addNewSidebarItem = RSImage.systemImage("plus")
			static let sidebarToggle = RSImage.systemImage("sidebar.left")
			static let refresh = RSImage.systemImage("arrow.clockwise")
			static let articleTheme = RSImage.systemImage("doc.richtext")
			static let cleanUpImage = RSImage.systemImage("wind")
			static let nextUnread = RSImage.systemImage("chevron.down.circle")
			static let openInBrowser = RSImage.systemImage("safari")
			static let readClosed = RSImage.systemImage("largecircle.fill.circle")
			static let readOpen = RSImage.systemImage("circle")
			static let share = AppAsset.shareImage
		}

		struct PreferencesToolbar {
			static let accounts = RSImage.systemImage("at")
			static let general = RSImage.systemImage("gearshape")
			static let advanced = RSImage.systemImage("gearshape.2")
		}

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
