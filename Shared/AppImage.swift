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

	// MARK: - Article Extractor

	static var articleExtractorError = RSImage(named: "articleExtractorError")!
	static var articleExtractorOff = RSImage(named: "articleExtractorOff")!
	static var articleExtractorOn = RSImage(named: "articleExtractorOn")!

#if os(iOS)
	static var articleExtractorOffSF = UIImage(systemName: "doc.plaintext")!
	static var articleExtractorOnSF = UIImage(named: "articleExtractorOnSF")!
	static var articleExtractorOffTinted = articleExtractorOff.tinted(color: AppAssets.primaryAccentColor)!
	static var articleExtractorOnTinted = articleExtractorOn.tinted(color: AppAssets.primaryAccentColor)!
#endif

	// MARK: - Action Images

	static var markAllAsRead = RSImage(named: "markAllAsRead")!

	// MARK: - Misc.

	static let nnwFeedIcon = RSImage(named: "nnwFeedIcon")!
}

// MARK: - Mac-only images

extension AppImage {

#if os(macOS)
	static var articleTheme = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)!
	static var cleanUp = NSImage(systemSymbolName: "wind", accessibilityDescription: nil)!
	static var marsEditIcon = RSImage(named: "MarsEditIcon")!
	static var microblogIcon = RSImage(named: "MicroblogIcon")!
#endif
}

// MARK: - iOS-only images

extension AppImage {

#if os(iOS)
	static var markBelowAsRead = UIImage(systemName: "arrowtriangle.down.circle")!
	static var markAboveAsRead = UIImage(systemName: "arrowtriangle.up.circle")!
	static var more = UIImage(systemName: "ellipsis.circle")!
	static var previousArticle = UIImage(systemName: "chevron.up")!
	static var nextArticle = UIImage(systemName: "chevron.down")!
	static var nextUnreadArticle = UIImage(systemName: "chevron.down.circle")!
	static var openInSidebar = UIImage(systemName: "arrow.turn.down.left")!
	static var safari = UIImage(systemName: "safari")!
	static var deactivate = UIImage(systemName: "minus.circle")!
	static var copy = UIImage(systemName: "doc.on.doc")!
	static var disclosure = UIImage(named: "disclosure")!
#endif
}

// MARK: - Private

private extension AppImage {

	// MARK: - Account Images

	static var accountBazQux = RSImage(named: "accountBazQux")!
	static var accountCloudKit = RSImage(named: "accountCloudKit")!
	static var accountFeedbin = RSImage(named: "accountFeedbin")!
	static var accountFeedly = RSImage(named: "accountFeedly")!
	static var accountFreshRSS = RSImage(named: "accountFreshRSS")!
	static var accountInoreader = RSImage(named: "accountInoreader")!
	static var accountNewsBlur = RSImage(named: "accountNewsBlur")!
	static var accountTheOldReader = RSImage(named: "accountTheOldReader")!

#if os(macOS)
	static var accountLocal = RSImage(named: "accountLocal")!
#elseif os(iOS)
	static var accountLocalPad = UIImage(named: "accountLocalPad")!
	static var accountLocalPhone = UIImage(named: "accountLocalPhone")!
	static var accountLocal = UIDevice.current.userInterfaceIdiom == .pad ? accountLocalPad : accountLocalPhone
#endif
}
