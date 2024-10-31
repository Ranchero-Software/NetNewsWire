//
//  AppAsset-Mac.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/30/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation
import Core
import Images

extension AppAsset {

	static let iconLightBackgroundColor = NSColor(named: "iconLightBackgroundColor")!
	static let iconDarkBackgroundColor = NSColor(named: "iconDarkBackgroundColor")!

	// MARK: - Mac Share Menu

	static let marsEditImage = RSImage.appImage("MarsEditIcon")
	static let microblogImage = RSImage.appImage("MicroblogIcon")

	// MARK: - Mac Toolbar

	static let toolbarAddNewSidebarItemImage = RSImage.systemImage("plus")
	static let toolbarRefreshImage = RSImage.systemImage("arrow.clockwise")
	static let toolbarArticleThemeImage = RSImage.systemImage("doc.richtext")
	static let toolbarCleanUpImage = RSImage.systemImage("wind")
	static let toolbarNextUnreadImage = RSImage.systemImage("chevron.down.circle")
	static let toolbarOpenInBrowserImage = RSImage.systemImage("safari")
	static let toolbarReadClosedImage = RSImage.systemImage("largecircle.fill.circle")
	static let toolbarReadOpenImage = RSImage.systemImage("circle")
	static let toolbarShareImage = AppAsset.shareImage

	// MARK: - Mac Preferences Toolbar

	static let preferencesToolbarAccountsImage = RSImage.systemImage("at")
	static let preferencesToolbarGeneralImage = RSImage.systemImage("gearshape")
	static let preferencesToolbarAdvancedImage = RSImage.systemImage("gearshape.2")

	// MARK: - Timeline

	static let timelineSwipeMarkRead = NSImage(systemSymbolName: "circle", accessibilityDescription: "Mark Read")!
		.withSymbolConfiguration(.init(scale: .large))
	static let timelineSwipeMarkUnread = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: "Mark Unread")!
		.withSymbolConfiguration(.init(scale: .large))
	static let timelineSwipeMarkStarred = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")!
		.withSymbolConfiguration(.init(scale: .large))
	static let timelineSwipeMarkUnstarred = NSImage(systemSymbolName: "star", accessibilityDescription: "Unstar")!
		.withSymbolConfiguration(.init(scale: .large))!
	static let timelineStarSelected = RSImage.appImage("timelineStar").tinted(with: .white)
	static let timelineStarUnselected = RSImage.appImage("timelineStar").tinted(with: AppAsset.starColor)
	static let timelineSeparatorColor = NSColor(named: "timelineSeparatorColor")!

	static let searchFeedImage: IconImage = {
		IconImage(NSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSupressed: true)
	}()

	static let folderIcon: IconImage = {
		let image = RSImage.systemImage("folder")
		let preferredColor = NSColor(named: "AccentColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let unreadFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "AccentColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let starredFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
		let preferredColor = AppAsset.starColor
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let todayFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)!
		let preferredColor = NSColor.orange
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()
}
