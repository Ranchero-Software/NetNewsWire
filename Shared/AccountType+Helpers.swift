//
//  AccountType+Helpers.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 27/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

extension AccountType {

	// TODO: Move this to the Account Package.

	func localizedAccountName() -> String {

		switch self {
		case .onMyMac:
			return NSLocalizedString("account.name.on-my-device", tableName: "DefaultAccountNames", comment: "Device specific default account name, e.g: On my iPhone")
		case .bazQux:
			return NSLocalizedString("BazQux", comment: "Account name")
		case .cloudKit:
			return NSLocalizedString("iCloud", comment: "Account name")
		case .feedbin:
			return NSLocalizedString("Feedbin", comment: "Account name")
		case .feedly:
			return NSLocalizedString("Feedly", comment: "Account name")
		case .freshRSS:
			return NSLocalizedString("FreshRSS", comment: "Account name")
		case .inoreader:
			return NSLocalizedString("Inoreader", comment: "Account name")
		case .newsBlur:
			return NSLocalizedString("NewsBlur", comment: "Account name")
		case .theOldReader:
			return NSLocalizedString("The Old Reader", comment: "Account name")
		}
	}

	// MARK: - SwiftUI Images
	func image() -> Image {
		switch self {
		case .onMyMac:
			// If it's the multiplatform app, the asset catalog contains assets for 
			#if os(macOS)
			return Image("accountLocal")
			#else
			if UIDevice.current.userInterfaceIdiom == .pad {
				return Image("accountLocalPad")
			} else {
				return Image("accountLocalPhone")
			}
			#endif
		case .bazQux:
			return Image("accountBazQux")
		case .cloudKit:
			return Image("accountCloudKit")
		case .feedbin:
			return Image("accountFeedbin")
		case .feedly:
			return Image("accountFeedly")
		case .freshRSS:
			return Image("accountFreshRSS")
		case .inoreader:
			return Image("accountInoreader")
		case .newsBlur:
			return Image("accountNewsBlur")
		case .theOldReader:
			return Image("accountTheOldReader")
		}
	}

}
