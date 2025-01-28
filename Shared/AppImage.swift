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

	static func accountImage(_ accountType: AccountType) -> RSImage? {
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
	static var markAllAsRead = appImage("markAllAsRead")
	static let nnwFeedIcon = RSImage(named: "nnwFeedIcon")!
	static var share = systemImage("square.and.arrow.up")
}

// MARK: - Mac

extension AppImage {

#if os(macOS)
	static var articleTheme = systemImage("doc.richtext")
	static var cleanUp = systemImage("wind")
	static var marsEditIcon = appImage("MarsEditIcon")
	static var microblogIcon = appImage("MicroblogIcon")
#endif
}

// MARK: - iOS

extension AppImage {

#if os(iOS)
	static var articleExtractorOffSF = systemImage("doc.plaintext")
	static var articleExtractorOnSF = appImage("articleExtractorOnSF")
	static var articleExtractorOffTinted = articleExtractorOff.tinted(color: AppAssets.primaryAccentColor)!
	static var articleExtractorOnTinted = articleExtractorOn.tinted(color: AppAssets.primaryAccentColor)!
	static var circleClosed = systemImage("largecircle.fill.circle")
	static var circleOpen = systemImage("circle")
	static var copy = systemImage("doc.on.doc")
	static var deactivate = systemImage("minus.circle")
	static var disclosure = appImage("disclosure")
	static var edit = systemImage("square.and.pencil")
	static var filterActive = systemImage("line.horizontal.3.decrease.circle.fill")
	static var filterInactive = systemImage("line.horizontal.3.decrease.circle")
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
	static var timelineStar = systemImage("star.fill").withTintColor(AppAssets.starColor, renderingMode: .alwaysOriginal)
	static var trash = systemImage("trash")

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
