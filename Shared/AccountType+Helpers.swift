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

extension AccountType {
	
	// TODO: Move this to the Account Package.
	
	func localizedAccountName() -> String {
		
		switch self {
		case .onMyMac:
			let defaultName: String
			#if os(macOS)
			defaultName = NSLocalizedString("On My Mac", comment: "Account name")
			#else
			if UIDevice.current.userInterfaceIdiom == .pad {
				defaultName = NSLocalizedString("On My iPad", comment: "Account name")
			} else {
				defaultName = NSLocalizedString("On My iPhone", comment: "Account name")
			}
			#endif
			return defaultName
		case .bazQux:
			return NSLocalizedString("BazQux", comment: "Account name")
		case .cloudKit:
			return NSLocalizedString("iCloud", comment: "Account name")
		case .feedWrangler:
			return NSLocalizedString("FeedWrangler", comment: "Account name")
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

}
