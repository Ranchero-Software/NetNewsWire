//
//  AppImage.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/26/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import RSCore
import Account

struct AppImage {

	// MARK: - Account

	static func account(_ accountType: AccountType) -> RSImage? {
		switch accountType {
		case .onMyMac:
			AppImage.accountLocal
		case .cloudKit:
			AppImage.accountCloudKit
		case .feedbin:
			AppImage.accountFeedbin
		case .feedly:
			AppImage.accountFeedly
		case .freshRSS:
			AppImage.accountFreshRSS
		case .newsBlur:
			AppImage.accountNewsBlur
		case .inoreader:
			AppImage.accountInoreader
		case .bazQux:
			AppImage.accountBazQux
		case .theOldReader:
			AppImage.accountTheOldReader
		}
	}

	static var articleExtractorError = appImage("articleExtractorError")
	static var articleExtractorOff = appImage("articleExtractorOff")
	static var articleExtractorOn = appImage("articleExtractorOn")
	static var faviconTemplate = appImage("faviconTemplateImage")
	static var filterActive = systemImage("line.horizontal.3.decrease.circle.fill")
	static var filterInactive = systemImage("line.horizontal.3.decrease.circle")
	static var markAllAsRead = appImage("markAllAsRead")
	static let nnwFeedIcon = RSImage(named: "nnwFeedIcon")!
	static var share = systemImage("square.and.arrow.up")
	static var starClosed = systemImage("star.fill")
	static var starOpen = systemImage("star")
}

// MARK: - Mac

extension AppImage {

#if os(macOS)
	static var addNewSidebarItem = systemImage("plus")
	static var articleTheme = systemImage("doc.richtext")
	static var cleanUp = systemImage("wind")
	static var marsEditIcon = appImage("MarsEditIcon")
	static var microblogIcon = appImage("MicroblogIcon")
	static var nextUnread = systemImage("chevron.down.circle")
	static var openInBrowser = systemImage("safari")
	static var preferencesToolbarAccounts = systemImage("at")
	static var preferencesToolbarAdvanced = systemImage("gearshape.2")
	static var preferencesToolbarGeneral = systemImage("gearshape")
	static var readClosed = systemImage("largecircle.fill.circle")
	static var readOpen = systemImage("circle")
	static var refresh = systemImage("arrow.clockwise")
	static var timelineStarSelected = appImage("timelineStar").tinted(with: .white)
	static var timelineStarUnselected = appImage("timelineStar").tinted(with: AppColor.star)

	static var swipeMarkRead: RSImage = {
		RSImage(systemSymbolName: "circle", accessibilityDescription: "Mark Read")!
			.withSymbolConfiguration(.init(scale: .large))!
	}()

	static var swipeMarkUnread: RSImage = {
		RSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: "Mark Unread")!
			.withSymbolConfiguration(.init(scale: .large))!
	}()

	static var swipeMarkStarred: RSImage = {
		RSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")!
			.withSymbolConfiguration(.init(scale: .large))!
	}()

	static var swipeMarkUnstarred: RSImage = {
		RSImage(systemSymbolName: "star", accessibilityDescription: "Unstar")!
			.withSymbolConfiguration(.init(scale: .large))!
	}()

	// IconImages

	static var searchFeed = IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSuppressed: true)

	// TODO: handle color palette change

	static var starredFeed: IconImage = {
		let image = systemImage("star.fill")
		let preferredColor = AppColor.star
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()

	static var todayFeed: IconImage = {
		let image = systemImage("sun.max.fill")
		let preferredColor = NSColor.orange
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()

	static var unreadFeed: IconImage = {
		let image = systemImage("largecircle.fill.circle")
		let preferredColor = AppColor.accent
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()

	static var folder: IconImage = {
		let image = systemImage("folder")
		let preferredColor = AppColor.accent
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSuppressed: true, preferredColor: preferredColor.cgColor)
	}()
#endif
}

// MARK: - iOS

extension AppImage {

#if os(iOS)
	static var allUnread = systemImage("largecircle.fill.circle")
	static var articleExtractorOffSF = systemImage("doc.plaintext")
	static var articleExtractorOnSF = appImage("articleExtractorOnSF")
	static var articleExtractorOffTinted = articleExtractorOff.tinted(color: AppColor.accent)!
	static var articleExtractorOnTinted = articleExtractorOn.tinted(color: AppColor.accent)!
	static var circleClosed = systemImage("largecircle.fill.circle")
	static var circleOpen = systemImage("circle")
	static var copy = systemImage("doc.on.doc")
	static var deactivate = systemImage("minus.circle")
	static var disclosure = appImage("disclosure")
	static var edit = systemImage("square.and.pencil")
	static var folderOutlinePlus = systemImage("folder.badge.plus")
	static var info = systemImage("info.circle")
	static var markBelowAsRead = systemImage("arrowtriangle.down.circle")
	static var markAboveAsRead = systemImage("arrowtriangle.up.circle")
	static var more = systemImage("ellipsis.circle")
	static var nextArticle = systemImage("chevron.down")
	static var nextUnreadArticle = systemImage("chevron.down.circle")
	static var openInSidebar = systemImage("arrow.turn.down.left")
	static var plus = systemImage("plus")
	static var previousArticle = systemImage("chevron.up")
	static var safari = systemImage("safari")
	static var settings = systemImage("gear")
	static var starred = systemImage("star.fill")
	static var timelineStar = systemImage("star.fill").withTintColor(AppColor.star, renderingMode: .alwaysOriginal)
	static var today = systemImage("sun.max.fill")
	static var trash = systemImage("trash")

	// IconImages

	static var searchFeed = IconImage(systemImage("magnifyingglass"), isSymbol: true)

	// TODO: handle color palette change

	static var starredFeed = IconImage(starred, isSymbol: true, isBackgroundSuppressed: true, preferredColor: AppColor.star.cgColor)
	static var todayFeed = IconImage(today, isSymbol: true, isBackgroundSuppressed: true, preferredColor: UIColor.systemOrange.cgColor)
	static var unreadFeed = IconImage(allUnread, isSymbol: true, isBackgroundSuppressed: true, preferredColor: AppColor.secondaryAccent.cgColor)

	static var folder: IconImage = {
		let image = systemImage("folder.fill")
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: AppColor.secondaryAccent.cgColor)
	}()
#endif
}

// MARK: - Private

private extension AppImage {

	// MARK: - Account Images

	static var accountBazQux = appImage("accountBazQux")
	static var accountCloudKit = appImage("accountCloudKit")
	static var accountFeedbin = appImage("accountFeedbin")
	static var accountFeedly = appImage("accountFeedly")
	static var accountFreshRSS = appImage("accountFreshRSS")
	static var accountInoreader = appImage("accountInoreader")
	static var accountNewsBlur = appImage("accountNewsBlur")
	static var accountTheOldReader = appImage("accountTheOldReader")

#if os(macOS)
	static var accountLocal = appImage("accountLocal")
#elseif os(iOS)
	static var accountLocalPad = appImage("accountLocalPad")
	static var accountLocalPhone = appImage("accountLocalPhone")
	static var accountLocal = UIDevice.current.userInterfaceIdiom == .pad ? accountLocalPad : accountLocalPhone
#endif

	static func appImage(_ name: String) -> RSImage {
		RSImage(named: name)!
	}

	static func systemImage(_ name: String) -> RSImage {
#if os(macOS)
		RSImage(systemSymbolName: name, accessibilityDescription: nil)!
#elseif os(iOS)
		UIImage(systemName: name)!
#endif
	}
}
