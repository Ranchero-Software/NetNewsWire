//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Account

struct AppAssets {

	static let accountBazQux = NSImage(named: "accountBazQux")

	static let accountCloudKit = NSImage(named: "accountCloudKit")

	static let accountFeedbin = NSImage(named: "accountFeedbin")

	static let accountFeedly = NSImage(named: "accountFeedly")
	
	static let accountFreshRSS = NSImage(named: "accountFreshRSS")

	static let accountInoreader = NSImage(named: "accountInoreader")

	static let accountLocal = NSImage(named: "accountLocal")

	static let accountNewsBlur = NSImage(named: "accountNewsBlur")

	static let accountTheOldReader = NSImage(named: "accountTheOldReader")

	static let addNewSidebarItemImage = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)!

	static let articleExtractorError = NSImage(named: "articleExtractorError")!

	static let articleExtractorOff = NSImage(named: "articleExtractorOff")!

	static let articleExtractorOn = NSImage(named: "articleExtractorOn")!

	static let articleTheme = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)!

	static let cleanUpImage = NSImage(systemSymbolName: "wind", accessibilityDescription: nil)!

	static let marsEditIcon = NSImage(named: "MarsEditIcon")!

	static let microblogIcon = NSImage(named: "MicroblogIcon")!

	static let faviconTemplateImage = NSImage(named: "faviconTemplateImage")!

	static let filterActive = NSImage(systemSymbolName: "line.horizontal.3.decrease.circle.fill", accessibilityDescription: nil)!

	static let filterInactive = NSImage(systemSymbolName: "line.horizontal.3.decrease.circle", accessibilityDescription: nil)!

	static let iconLightBackgroundColor = NSColor(named: NSColor.Name("iconLightBackgroundColor"))!

	static let iconDarkBackgroundColor = NSColor(named: NSColor.Name("iconDarkBackgroundColor"))!

	static let legacyArticleExtractor = NSImage(named: "legacyArticleExtractor")!

	static let legacyArticleExtractorError = NSImage(named: "legacyArticleExtractorError")!

	static let legacyArticleExtractorInactiveDark = NSImage(named: "legacyArticleExtractorInactiveDark")!

	static let legacyArticleExtractorInactiveLight = NSImage(named: "legacyArticleExtractorInactiveLight")!

	static let legacyArticleExtractorProgress1 = NSImage(named: "legacyArticleExtractorProgress1")

	static let legacyArticleExtractorProgress2 = NSImage(named: "legacyArticleExtractorProgress2")

	static let legacyArticleExtractorProgress3 = NSImage(named: "legacyArticleExtractorProgress3")

	static let legacyArticleExtractorProgress4 = NSImage(named: "legacyArticleExtractorProgress4")

	static let folderImage: IconImage = {
		let image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "AccentColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let markAllAsReadImage = NSImage(named: "markAllAsRead")!

	static let nextUnreadImage = NSImage(systemSymbolName: "chevron.down.circle", accessibilityDescription: nil)!

	static let openInBrowserImage = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)!

	static let preferencesToolbarAccountsImage = NSImage(systemSymbolName: "at", accessibilityDescription: nil)!

	static let preferencesToolbarGeneralImage = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)!

	static let preferencesToolbarAdvancedImage = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: nil)!

	static let readClosedImage = NSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: nil)!

	static let readOpenImage = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)!
	
	static let refreshImage = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)!

	static let searchFeedImage: IconImage = {
		return IconImage(NSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSupressed: true)
	}()
	
	static let shareImage = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)!

	static let sidebarToggleImage = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: nil)!

	static let starClosedImage = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!

	static let starOpenImage = NSImage(systemSymbolName: "star", accessibilityDescription: nil)!

	static let starredFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!
		let preferredColor = NSColor(named: "StarColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

	static let timelineSeparatorColor = NSColor(named: "timelineSeparatorColor")!

	static let timelineStarSelected = NSImage(named: "timelineStar")?.tinted(with: .white)

	static let timelineStarUnselected = NSImage(named: "timelineStar")?.tinted(with: starColor)

	static let todayFeedImage: IconImage = {
		let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)!
		let preferredColor = NSColor.orange
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()

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

	static func image(for accountType: AccountType) -> NSImage? {
		switch accountType {
		case .onMyMac:
			return AppAssets.accountLocal
		case .cloudKit:
			return AppAssets.accountCloudKit
		case .bazQux:
			return AppAssets.accountBazQux
		case .feedbin:
			return AppAssets.accountFeedbin
		case .feedly:
			return AppAssets.accountFeedly
		case .freshRSS:
			return AppAssets.accountFreshRSS
		case .inoreader:
			return AppAssets.accountInoreader
		case .newsBlur:
			return AppAssets.accountNewsBlur
		case .theOldReader:
			return AppAssets.accountTheOldReader
		}
	}
}
