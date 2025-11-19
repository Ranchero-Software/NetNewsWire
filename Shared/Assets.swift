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

#if os(macOS)
typealias RSColor = NSColor
#else
typealias RSColor = UIColor
#endif

struct Assets {
	struct Images {
		static var accountBazQux: RSImage { RSImage(named: "accountBazQux")! }
		static var accountCloudKit: RSImage { RSImage(named: "accountCloudKit")! }
		static var accountFeedbin: RSImage { RSImage(named: "accountFeedbin")! }
		static var accountFeedly: RSImage { RSImage(named: "accountFeedly")! }
		static var accountFreshRSS: RSImage { RSImage(named: "accountFreshRSS")! }
		static var accountInoreader: RSImage { RSImage(named: "accountInoreader")! }
		static var accountNewsBlur: RSImage { RSImage(named: "accountNewsBlur")! }
		static var accountTheOldReader: RSImage { RSImage(named: "accountTheOldReader")! }

		static var starOpen: RSImage { RSImage(symbol: "star")! }
		static var starClosed: RSImage { RSImage(symbol: "star.fill")! }
		static var copy: RSImage { RSImage(symbol: "document.on.document")! }
		static var markAllAsRead: RSImage { RSImage(named: "markAllAsRead")! }
		static var nextUnread: RSImage { RSImage(symbol: "chevron.down.circle")! }

		static var nnwFeedIcon: RSImage { RSImage(named: "nnwFeedIcon")! }
		static var faviconTemplate: RSImage { RSImage(named: "faviconTemplateImage")! }

		static var articleExtractorError: RSImage { RSImage(named: "articleExtractorError")! }
		static var articleExtractorOn: RSImage { RSImage(named: "articleExtractorOn")! }
		static var articleExtractorOff: RSImage { RSImage(named: "articleExtractorOff")! }
		static var share: RSImage { RSImage(symbol: "square.and.arrow.up")! }
		static var folder: RSImage { RSImage(symbol: "folder")! }
		static var starredFeed: IconImage {
			IconImage(starClosed,
					  isSymbol: true,
					  isBackgroundSuppressed: true,
					  preferredColor: Assets.Colors.star.cgColor)
		}

#if os(macOS)
		static var accountLocal: RSImage { RSImage(named: "accountLocal")! }
		static var addNewSidebarItem: RSImage { RSImage(symbol: "plus")! }
		static var articleTheme: RSImage { RSImage(symbol: "doc.richtext")! }
		static var cleanUp: RSImage { RSImage(symbol: "bubbles.and.sparkles")! }
		static var delete: RSImage { RSImage(symbol: "xmark.bin")! }
		static var marsEdit: RSImage { RSImage(named: "MarsEditIcon")! }
		static var microblog: RSImage { RSImage(named: "MicroblogIcon")! }
		static var filterActive: RSImage { RSImage(symbol: "line.horizontal.3.decrease.circle.fill")! }
		static var filterInactive: RSImage { RSImage(symbol: "line.horizontal.3.decrease.circle")! }
		static var markAllAsReadMenu: RSImage { RSImage(named: "markAllAsRead")! }
		static var notification: RSImage { RSImage(symbol: "bell.badge")! }
		static var openInBrowser: RSImage { RSImage(symbol: "safari")! }
		static var preferencesToolbarAccounts: RSImage { RSImage(symbol: "at")! }
		static var preferencesToolbarGeneral: RSImage { RSImage(symbol: "gearshape")! }
		static var preferencesToolbarAdvanced: RSImage { RSImage(symbol: "gearshape.2")! }
		static var readClosed: RSImage { RSImage(symbol: "largecircle.fill.circle")! }
		static var readOpen: RSImage { RSImage(symbol: "circle")! }
		static var refresh: RSImage { RSImage(symbol: "arrow.clockwise")! }
		static var rename: RSImage { RSImage(symbol: "pencil")! }
		static var swipeMarkUnstarred: RSImage { RSImage(symbol: "star")! }
		static var timelineStarSelected: RSImage { RSImage(named: "timelineStar")!.tinted(with: .white) }
		static var timelineStarUnselected: RSImage { RSImage(named: "timelineStar")!.tinted(with: Assets.Colors.star) }
		static var markBelowAsRead: RSImage { RSImage(named: "markBelowAsRead")! }
		static var markAboveAsRead: RSImage { RSImage(named: "markAboveAsRead")! }
		static var searchFeed: IconImage {
			IconImage(RSImage(named: NSImage.smartBadgeTemplateName)!, isSymbol: true, isBackgroundSuppressed: true)
		}
		static var swipeMarkStarred: RSImage {
			RSImage(systemSymbolName: "star.fill", accessibilityDescription: "Star")!
		}
		static var swipeMarkRead: RSImage {
			RSImage(systemSymbolName: "circle", accessibilityDescription: "Mark Read")!
		}
		static var swipeMarkUnread: RSImage {
			RSImage(systemSymbolName: "largecircle.fill.circle", accessibilityDescription: "Mark Unread")!
		}
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
		static var articleExtractorOffSF: RSImage { RSImage(symbol: "doc.plaintext")! }
		@MainActor static var articleExtractorOnTinted: RSImage {
			articleExtractorOn.tinted(color: Assets.Colors.primaryAccent)!
		}
		@MainActor static var articleExtractorOffTinted: RSImage {
			articleExtractorOff.tinted(color: Assets.Colors.primaryAccent)!
		}

		static var circleClosed: RSImage { RSImage(symbol: "largecircle.fill.circle")! }
		static var markBelowAsRead: RSImage { RSImage(symbol: "arrowtriangle.down.circle")! }
		static var markAboveAsRead: RSImage { RSImage(named: "arrowtriangle.up.circle")! }
		static var more: RSImage { RSImage(symbol: "ellipsis.circle")! }
		static var nextArticle: RSImage { RSImage(symbol: "chevron.down")! }
		static var circleOpen: RSImage { RSImage(symbol: "circle")! }
		static var disclosure: RSImage { RSImage(named: "disclosure")! }
		static var deactivate: RSImage { RSImage(symbol: "minus.circle")! }
		static var edit: RSImage { RSImage(symbol: "square.and.pencil")! }
		static var filter: RSImage { RSImage(symbol: "line.3.horizontal.decrease")! }
		static var folderOutlinePlus: RSImage { RSImage(symbol: "folder.badge.plus")! }
		static var info: RSImage { RSImage(symbol: "info.circle")! }
		static var plus: RSImage { RSImage(symbol: "plus")! }
		static var prevArticle: RSImage { RSImage(symbol: "chevron.up")! }
		static var openInSidebar: RSImage { RSImage(symbol: "arrow.turn.down.left")! }
		static var safari: RSImage { RSImage(symbol: "safari")! }
		static var smartFeed: RSImage { RSImage(symbol: "gear")! }
		static var trash: RSImage { RSImage(symbol: "trash")! }

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

	struct Colors {
#if os(macOS)
		static var primaryAccent: RSColor { RSColor(named: "AccentColor")! }
		static var timelineSeparator: RSColor { NSColor(named: "timelineSeparatorColor")! }
		static var iconLightBackground: RSColor { NSColor(named: "iconLightBackgroundColor")! }
		static var iconDarkBackground: RSColor { NSColor(named: "iconDarkBackgroundColor")! }
		static var star: RSColor { RSColor(named: "StarColor")! }
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
