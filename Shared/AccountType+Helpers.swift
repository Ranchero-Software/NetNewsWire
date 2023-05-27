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
			let defaultName: String
			#if os(macOS)
			defaultName = NSLocalizedString("account.name.mac", comment: "On My Mac")
			#else
			if UIDevice.current.userInterfaceIdiom == .pad {
				defaultName = NSLocalizedString("account.name.ipad", comment: "On My iPad")
			} else {
				defaultName = NSLocalizedString("account.name.iphone", comment: "On My iPhone")
			}
			#endif
			return defaultName
		
		/* The below account names are not localized as they are product names. */
			
		case .bazQux:
			return "BazQux"
		case .cloudKit:
			return "iCloud"
		case .feedbin:
			return "Feedbin"
		case .feedly:
			return "Feedly"
		case .freshRSS:
			return "FreshRSS"
		case .inoreader:
			return "Inoreader"
		case .newsBlur:
			return "NewsBlur"
		case .theOldReader:
			return "The Old Reader"
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
