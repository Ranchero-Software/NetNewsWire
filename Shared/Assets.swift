//
//  Assets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/18/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
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

		#if os(macOS)
		static var accountLocal: RSImage { RSImage(named: "accountLocal")! }
		#else // iOS
		static var accountLocalPadImage: RSImage { RSImage(named: "accountLocalPad")! }
		static var accountLocalPhoneImage: RSImage { RSImage(named: "accountLocalPhone")! }
		#endif
	}

	static func accountImage(_ accountType: AccountType) -> RSImage {
		switch accountType {
		case .onMyMac:
			#if os(macOS)
			return Assets.Images.accountLocal
			#else // iOS
			if UIDevice.current.userInterfaceIdiom == .pad {
				return AppAssets.accountLocalPadImage
			} else {
				return AppAssets.accountLocalPhoneImage
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
