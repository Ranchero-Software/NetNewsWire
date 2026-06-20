//
//  Assets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/18/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

import RSCore
import Account
import Images

#if os(macOS)
typealias RSColor = NSColor
#else
typealias RSColor = UIColor
#endif

struct Assets {
	@MainActor struct Images {
		static var accountBazQux: RSImage { RSImage(named: "accountBazQux")! }
		static var accountCloudKit: RSImage { RSImage(named: "accountCloudKit")! }
		static var accountFeedbin: RSImage { RSImage(named: "accountFeedbin")! }
		static var accountFeedly: RSImage { RSImage(named: "accountFeedly")! }
		static var accountFreshRSS: RSImage { RSImage(named: "accountFreshRSS")! }
		static var accountInoreader: RSImage { RSImage(named: "accountInoreader")! }
		static var accountNewsBlur: RSImage { RSImage(named: "accountNewsBlur")! }
		static var accountTheOldReader: RSImage { RSImage(named: "accountTheOldReader")! }

		static let starOpen = RSImage(symbol: "star")!
		static let starClosed = RSImage(symbol: "star.fill")!
		static let copy = RSImage(symbol: "document.on.document")
		static var markAllAsRead: RSImage { RSImage(named: "markAllAsRead")! }
		static let nextUnread = RSImage(symbol: "chevron.down.circle")!

		nonisolated static var nnwFeedIcon: RSImage { RSImage(named: "nnwFeedIcon")! }
		static var faviconTemplate: RSImage { RSImage(named: "faviconTemplateImage")! }

		static var articleExtractorError: RSImage { RSImage(named: "articleExtractorError")! }
		static var articleExtractorOn: RSImage { RSImage(named: "articleExtractorOn")! }
		static var articleExtractorOff: RSImage { RSImage(named: "articleExtractorOff")! }
		static let share = RSImage(symbol: "square.and.arrow.up")!
		static let folder = RSImage(symbol: "folder")!
		static var starredFeed: IconImage {
			IconImage(starClosed,
					  isSymbol: true,
					  isBackgroundSuppressed: true,
					  preferredColor: Assets.Colors.star.cgColor)
		}

#if os(macOS)
		static var accountLocal: RSImage { RSImage(named: "accountLocal")! }
		static let addNewSidebarItem = RSImage(symbol: "plus")!
		static let articleTheme = RSImage(symbol: "doc.richtext")!
		static let cleanUp = RSImage(symbol: "bubbles.and.sparkles")!
		static var marsEdit: RSImage { RSImage(named: "MarsEditIcon")! }
		static var microblog: RSImage { RSImage(named: "MicroblogIcon")! }
		static let filterActive = RSImage(symbol: "line.horizontal.3.decrease.circle.fill")!
		static let filterInactive = RSImage(symbol: "line.horizontal.3.decrease.circle")!
		static let openInBrowser = RSImage(symbol: "safari")!
		static let preferencesToolbarAccounts = RSImage(symbol: "at")!
		static let preferencesToolbarGeneral = RSImage(symbol: "gearshape")!
		static let preferencesToolbarAdvanced = RSImage(symbol: "gearshape.2")!
		static let readClosed = RSImage(symbol: "largecircle.fill.circle")!
		static let readOpen = RSImage(symbol: "circle")!
		static let refresh = RSImage(symbol: "arrow.clockwise")!
		static let swipeMarkUnstarred = RSImage(symbol: "star")!
		static var timelineStar: RSImage { RSImage(named: "timelineStar")! }
		static var markBelowAsRead: RSImage { RSImage(named: "markBelowAsRead")! }
		static var markAboveAsRead: RSImage { RSImage(named: "markAboveAsRead")! }
		static var searchFeed: IconImage {
			IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSuppressed: true)
		}
		static let swipeMarkStarred = RSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")!
		static let swipeMarkRead = RSImage(systemSymbolName: "circle", accessibilityDescription: "Mark Read")!
		static let swipeMarkUnread = RSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: "Mark Unread")!
		static var mainFolder: IconImage {
			IconImage(folder,
					  isSymbol: true,
					  isBackgroundSuppressed: true,
					  preferredColor: Assets.Colors.primaryAccent.cgColor)
		}
		static var todayFeed: IconImage {
			let image = RSImage(symbol: "sun.max.fill")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: NSColor.orange.cgColor)
		}
		static var unreadFeed: IconImage {
			let image = RSImage(symbol: "largecircle.fill.circle")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: Assets.Colors.primaryAccent.cgColor)
		}

#else // iOS
		static var accountLocalPadImage: RSImage { RSImage(named: "accountLocalPad")! }
		static var accountLocalPhoneImage: RSImage { RSImage(named: "accountLocalPhone")! }

		static var articleExtractorOnSF: RSImage { RSImage(named: "articleExtractorOnSF")! }
		static let articleExtractorOffSF = RSImage(symbol: "doc.plaintext")!
		static var articleExtractorOnTinted: RSImage {
			articleExtractorOn.tinted(color: Assets.Colors.primaryAccent)!
		}
		static var articleExtractorOffTinted: RSImage {
			articleExtractorOff.tinted(color: Assets.Colors.primaryAccent)!
		}

		static let circleClosed = RSImage(symbol: "largecircle.fill.circle")!
		static let markBelowAsRead = RSImage(symbol: "arrowtriangle.down.circle")!
		static let markAboveAsRead = RSImage(symbol: "arrowtriangle.up.circle")!
		static let more = RSImage(symbol: "ellipsis.circle")!
		static let nextArticle = RSImage(symbol: "chevron.down")!
		static let circleOpen = RSImage(symbol: "circle")!
		static var disclosure: RSImage { RSImage(named: "disclosure")! }
		static let deactivate = RSImage(symbol: "minus.circle")!
		static let currentActivity = RSImage(symbol: "text.pad.header")!
		static let edit = RSImage(symbol: "square.and.pencil")!
		static let filter = RSImage(symbol: "line.3.horizontal.decrease")!
		static let folderOutlinePlus = RSImage(symbol: "folder.badge.plus")!
		static let info = RSImage(symbol: "info.circle")!
		static let plus = RSImage(symbol: "plus")!
		static let prevArticle = RSImage(symbol: "chevron.up")!
		static let openInSidebar = RSImage(symbol: "arrow.turn.down.left")!
		static let safari = RSImage(symbol: "safari")!
		static let smartFeed = RSImage(symbol: "gear")!
		static let trash = RSImage(symbol: "trash")!

		static var searchFeed: IconImage {
			IconImage(RSImage(symbol: "magnifyingglass")!, isSymbol: true)
		}
		static var mainFolder: IconImage {
			IconImage(folder,
					  isSymbol: true,
					  isBackgroundSuppressed: true,
					  preferredColor: Assets.Colors.secondaryAccent.cgColor)
		}
		static var todayFeed: IconImage {
			let image = RSImage(symbol: "sun.max.fill")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: UIColor.systemOrange.cgColor)
		}
		static var unreadFeed: IconImage {
			let image = RSImage(symbol: "largecircle.fill.circle")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: Assets.Colors.secondaryAccent.cgColor)
		}
		static var timelineStar: RSImage {
			let image = RSImage(symbol: "star.fill")!
			return image.withTintColor(Assets.Colors.star, renderingMode: .alwaysOriginal)
		}
		static var unreadCellIndicator: IconImage {
			let image = RSImage(symbol: "circle.fill")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: Assets.Colors.secondaryAccent.cgColor)
		}
#endif
	}

	@MainActor static func accountImage(_ accountType: AccountType) -> RSImage {
		switch accountType {
		case .onMyMac:
#if os(macOS)
			return Assets.Images.accountLocal
#else // iOS
			if UIDevice.current.userInterfaceIdiom == .pad {
				return Assets.Images.accountLocalPadImage
			} else {
				return Assets.Images.accountLocalPhoneImage
			}
#endif
		case .cloudKit:
			return Assets.Images.accountCloudKit
		case .bazQux:
			return Assets.Images.accountBazQux
		case .feedbin:
			return Assets.Images.accountFeedbin
		case .feedly:
			return Assets.Images.accountFeedly
		case .freshRSS:
			return Assets.Images.accountFreshRSS
		case .inoreader:
			return Assets.Images.accountInoreader
		case .newsBlur:
			return Assets.Images.accountNewsBlur
		case .theOldReader:
			return Assets.Images.accountTheOldReader
		}
	}

	@MainActor struct Colors {
#if os(macOS)
		static var primaryAccent: RSColor { RSColor(named: "AccentColor")! }
		static var timelineSeparator: RSColor { NSColor(named: "timelineSeparatorColor")! }
		static var iconLightBackground: RSColor { NSColor(named: "iconLightBackgroundColor")! }
		static var iconDarkBackground: RSColor { NSColor(named: "iconDarkBackgroundColor")! }
		static var star: RSColor { RSColor(named: "StarColor")! }
		static var sidebarUnreadCountBackground: RSColor { RSColor(named: "SidebarUnreadCountBackground")! }
		static var sidebarUnreadCountText: RSColor { RSColor(named: "SidebarUnreadCountText")! }
#else // iOS
		static var primaryAccent: RSColor { RSColor(named: "primaryAccentColor")! }
		static var secondaryAccent: RSColor { RSColor(named: "secondaryAccentColor")! }
		static var star: RSColor { RSColor(named: "starColor")! }
		static var vibrantText: RSColor { RSColor(named: "vibrantTextColor")! }
		static var controlBackground: RSColor { RSColor(named: "controlBackgroundColor")! }
		static var iconBackground: RSColor { RSColor(named: "iconBackgroundColor")! }
		static var fullScreenBackground: RSColor { RSColor(named: "fullScreenBackgroundColor")! }
		static var sectionHeader: RSColor { RSColor(named: "sectionHeaderColor")! }
#endif
	}
}

extension RSImage {

	convenience init?(symbol: String) {
#if os(macOS)
		self.init(systemSymbolName: symbol, accessibilityDescription: nil)
#else // iOS
		self.init(systemName: symbol)
#endif
	}
}
