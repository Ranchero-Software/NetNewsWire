//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import Account

struct AppAssets {
	static let nnwFeedIcon = RSImage(named: "nnwFeedIcon")!
	static let addNewSidebarItemImage = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)!
	static let articleExtractorError = RSImage(named: "articleExtractorError")!
	static let articleExtractorOff = RSImage(named: "articleExtractorOff")!
	static let articleExtractorOn = RSImage(named: "articleExtractorOn")!
	static let articleTheme = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)!
	static let cleanUpImage = NSImage(systemSymbolName: "bubbles.and.sparkles", accessibilityDescription: nil)!
	static let copyImage = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: nil)!
	static let deleteImage = NSImage(systemSymbolName: "xmark.bin", accessibilityDescription: nil)!
	static let marsEditIcon = RSImage(named: "MarsEditIcon")!
	static let microblogIcon = RSImage(named: "MicroblogIcon")!
	static let faviconTemplateImage = RSImage(named: "faviconTemplateImage")!
	static let filterActive = NSImage(systemSymbolName: "line.horizontal.3.decrease.circle.fill", accessibilityDescription: nil)!
	static let filterInactive = NSImage(systemSymbolName: "line.horizontal.3.decrease.circle", accessibilityDescription: nil)!
	static let iconLightBackgroundColor = NSColor(named: NSColor.Name("iconLightBackgroundColor"))!
	static let iconDarkBackgroundColor = NSColor(named: NSColor.Name("iconDarkBackgroundColor"))!

	static let mainFolderImage: IconImage = {
		let image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "AccentColor")!
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()


	static let markAllAsReadMenuImage = RSImage(named: "markAllAsRead")!
	static let markAllAsReadImage = RSImage(named: "markAllAsRead")!
	static let markBelowAsReadImage = RSImage(named: "markBelowAsRead")!
	static let markAboveAsReadImage = RSImage(named: "markAboveAsRead")!

	static let nextUnreadImage = NSImage(systemSymbolName: "chevron.down.circle", accessibilityDescription: nil)!
	static let notificationImage = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: nil)!
	static let openInBrowserImage = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)!

	static let preferencesToolbarAccountsImage = NSImage(systemSymbolName: "at", accessibilityDescription: nil)!
	static let preferencesToolbarGeneralImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)!
	static let preferencesToolbarAdvancedImage = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: nil)!
	static let readClosedImage = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!
	static let readOpenImage = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)!
	static let refreshImage = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)!
	static let renameImage = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)!
	static let searchFeedImage = IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSuppressed: true)
	static let shareImage = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)!
	static let sidebarToggleImage = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)!

	static let starredFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "StarColor")!
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let timelineSeparatorColor = NSColor(named: "timelineSeparatorColor")!
	static let timelineStarSelected = RSImage(named: "timelineStar")?.tinted(with: .white)
	static let timelineStarUnselected = RSImage(named: "timelineStar")?.tinted(with: starColor)

	static let todayFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)!
		let preferredColor = NSColor.orange
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let unreadFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "AccentColor")!
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let swipeMarkReadImage = RSImage(systemSymbolName: "circle", accessibilityDescription: "Mark Read")!
	static let swipeMarkUnreadImage = RSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: "Mark Unread")!
	static let swipeMarkStarredImage = RSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")!
	static let swipeMarkUnstarredImage = RSImage(systemSymbolName: "star", accessibilityDescription: "Unstar")!
	static let starColor = NSColor(named: NSColor.Name("StarColor"))!
}
