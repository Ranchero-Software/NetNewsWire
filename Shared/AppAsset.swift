//
//  AppAsset.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/7/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

import Core
import Account
import Images

final class AppAsset {

	static let markAllAsReadImage = RSImage.appImage("markAllAsRead")
	static let faviconTemplateImage = RSImage.appImage("faviconTemplateImage")
	static let shareImage = RSImage.systemImage("square.and.arrow.up")

	static let starColor = RSColor(named: "starColor")!

	@MainActor static let folderIcon: IconImage = {

#if os(macOS)
		let image = RSImage.systemImage("folder")
		let preferredColor = NSColor(named: "AccentColor")!
		let coloredImage = image.tinted(with: preferredColor)
		return IconImage(coloredImage, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
#else
		let image = RSImage.systemImage("folder.fill")
		let preferredColor = AppAssets.secondaryAccentColor
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
#endif
	}()

	@MainActor static let searchFeedImage: IconImage = {

#if os(macOS)
		IconImage(NSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSupressed: true)
#else
		IconImage(UIImage(systemName: "magnifyingglass")!, isSymbol: true)
#endif
	}()

	// MARK: - ArticleExtractor

	static let articleExtractorErrorImage = RSImage.appImage("articleExtractorError")
	static let articleExtractorOffImage = RSImage.appImage("articleExtractorOff")
	static let articleExtractorOffSFImage = RSImage.systemImage("doc.plaintext")
	static let articleExtractorOnImage = RSImage.appImage("articleExtractorOn")
	static let articleExtractorOnSFImage = RSImage.appImage("articleExtractorOnSF")

	// MARK: - Filter icon

	static let filterActiveImage = RSImage.systemImage("line.horizontal.3.decrease.circle.fill")
	static let filterInactiveImage = RSImage.systemImage("line.horizontal.3.decrease.circle")
}

// MARK: - Account

extension AppAsset {

	static let bazQuxImage = RSImage.appImage("accountBazQux")
	static let cloudKitImage = RSImage.appImage("accountCloudKit")
	static let feedbinImage = RSImage.appImage("accountFeedbin")
	static let feedlyImage = RSImage.appImage("accountFeedly")
	static let freshRSSImage = RSImage.appImage("accountFreshRSS")
	static let inoReaderImage = RSImage.appImage("accountInoreader")
	static let localAccountMacImage = RSImage.appImage("accountLocal")
	static let localAccountPadImage = RSImage.appImage("accountLocalPad")
	static let localAccountPhoneImage = RSImage.appImage("accountLocalPhone")
	static let newsBlurImage = RSImage.appImage("accountNewsBlur")
	static let theOldReaderImage = RSImage.appImage("accountTheOldReader")

	@MainActor static func accountImage(for accountType: AccountType) -> RSImage {

		switch accountType {
		case .onMyMac:

#if os(macOS)
			return AppAsset.localAccountMacImage
#elseif os(iOS)
			if UIDevice.current.userInterfaceIdiom == .pad {
				return AppAsset.localAccountPadImage
			} else {
				return AppAsset.localAccountPhoneImage
			}
#endif

		case .cloudKit:
			return AppAsset.cloudKitImage
		case .bazQux:
			return AppAsset.bazQuxImage
		case .feedbin:
			return AppAsset.feedbinImage
		case .feedly:
			return AppAsset.feedlyImage
		case .freshRSS:
			return AppAsset.freshRSSImage
		case .inoreader:
			return AppAsset.inoReaderImage
		case .newsBlur:
			return AppAsset.newsBlurImage
		case .theOldReader:
			return AppAsset.theOldReaderImage
		}
	}
}

#if os(macOS)

// MARK: - Mac

extension AppAsset {

	static let iconLightBackgroundColor = NSColor(named: "iconLightBackgroundColor")!
	static let iconDarkBackgroundColor = NSColor(named: "iconDarkBackgroundColor")!

	// MARK: - Mac Share Menu

	static let marsEditImage = RSImage.appImage("MarsEditIcon")
	static let microblogImage = RSImage.appImage("MicroblogIcon")

	// MARK: - Mac Toolbar

	static let toolbarAddNewSidebarItemImage = RSImage.systemImage("plus")
	static let toolbarSidebarToggleImage = RSImage.systemImage("sidebar.left")
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
}

#endif

