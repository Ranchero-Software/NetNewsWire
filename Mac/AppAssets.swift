//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import Images
import Core

extension AppAsset {

	struct Mac {

		static let iconLightBackgroundColor = NSColor(named: NSColor.Name("iconLightBackgroundColor"))!
		static let iconDarkBackgroundColor = NSColor(named: NSColor.Name("iconDarkBackgroundColor"))!

		static let marsEditIcon = RSImage.appImage("MarsEditIcon")
		static let microblogIcon = RSImage.appImage("MicroblogIcon")

		struct Toolbar {
			static let addNewSidebarItem = RSImage.systemImage("plus")
			static let sidebarToggle = RSImage.systemImage("sidebar.left")
			static let refresh = RSImage.systemImage("arrow.clockwise")
			static let articleTheme = RSImage.systemImage("doc.richtext")
			static let cleanUpImage = RSImage.systemImage("wind")
		}
	}
}


struct AppAssets {



	static let legacyArticleExtractor = NSImage(named: "legacyArticleExtractor")!

	static let legacyArticleExtractorError = NSImage(named: "legacyArticleExtractorError")!

	static let legacyArticleExtractorInactiveDark = NSImage(named: "legacyArticleExtractorInactiveDark")!

	static let legacyArticleExtractorInactiveLight = NSImage(named: "legacyArticleExtractorInactiveLight")!

	static let legacyArticleExtractorProgress1 = NSImage(named: "legacyArticleExtractorProgress1")

	static let legacyArticleExtractorProgress2 = NSImage(named: "legacyArticleExtractorProgress2")

	static let legacyArticleExtractorProgress3 = NSImage(named: "legacyArticleExtractorProgress3")

	static let legacyArticleExtractorProgress4 = NSImage(named: "legacyArticleExtractorProgress4")

	@MainActor
	static let folderImage: IconImage = {
		let image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "AccentColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let nextUnreadImage = NSImage(systemSymbolName: "chevron.down.circle", accessibilityDescription: nil)!

	static let openInBrowserImage = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)!

	static let preferencesToolbarAccountsImage = NSImage(systemSymbolName: "at", accessibilityDescription: nil)!

	static let preferencesToolbarGeneralImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)!

	static let preferencesToolbarAdvancedImage = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: nil)!

	static let readClosedImage = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!

	static let readOpenImage = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)!
	

	@MainActor
	static let searchFeedImage: IconImage = {
		return IconImage(NSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSupressed: true)
	}()
	
	static let shareImage = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)!

	static let starClosedImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!

	static let starOpenImage = NSImage(systemSymbolName: "star", accessibilityDescription: nil)!

	@MainActor
	static let starredFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "StarColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let timelineSeparatorColor = NSColor(named: "timelineSeparatorColor")!

	static let timelineStarSelected = NSImage(named: "timelineStar")?.tinted(with: .white)

	static let timelineStarUnselected = NSImage(named: "timelineStar")?.tinted(with: starColor)

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

	static let swipeMarkReadImage = NSImage(systemSymbolName: "circle", accessibilityDescription: "Mark Read")!
		.withSymbolConfiguration(.init(scale: .large))

	static let swipeMarkUnreadImage = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: "Mark Unread")!
		.withSymbolConfiguration(.init(scale: .large))

	static let swipeMarkStarredImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")!
		.withSymbolConfiguration(.init(scale: .large))

	static let swipeMarkUnstarredImage = NSImage(systemSymbolName: "star", accessibilityDescription: "Unstar")!
		.withSymbolConfiguration(.init(scale: .large))!

	static let starColor = NSColor(named: NSColor.Name("StarColor"))!
}
