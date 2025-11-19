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

		static var nnwFeedIcon: RSImage { RSImage(named: "nnwFeedIcon")! }

		static var articleExtractorError: RSImage { RSImage(named: "articleExtractorError")! }
		static var articleExtractorOn: RSImage { RSImage(named: "articleExtractorOn")! }
		static var articleExtractorOff: RSImage { RSImage(named: "articleExtractorOff")! }

		#if os(macOS)
		static var accountLocal: RSImage { RSImage(named: "accountLocal")! }
		#else // iOS
		static var accountLocalPadImage: RSImage { RSImage(named: "accountLocalPad")! }
		static var accountLocalPhoneImage: RSImage { RSImage(named: "accountLocalPhone")! }
		static var articleExtractorOffSF: RSImage { RSImage(symbol: "doc.plaintext")! }
		static var circleClosed: RSImage { RSImage(symbol: "largecircle.fill.circle")! }
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
		static var timelineSeparator: NSColor { NSColor(named: "timelineSeparatorColor")! }
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
