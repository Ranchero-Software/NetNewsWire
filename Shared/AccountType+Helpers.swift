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
	// Colors
	
	#if os(macOS)
	func iconColor() -> NSColor {
		switch self {
		case .onMyMac:
			return NSColor(named: "localColor")!
		case .bazQux:
			return NSColor(named: "bazquxColor")!
		case .cloudKit:
			return NSColor(named: "cloudkitColor")!
		case .feedWrangler:
			return NSColor(named: "feedwranglerColor")!
		case .feedbin:
			return NSColor(named: "feedbinColor")!
		case .feedly:
			return NSColor(named: "feedlyColor")!
		case .freshRSS:
			return NSColor(named: "freshRSSColor")!
		case .inoreader:
			return NSColor(named: "inoreaderColor")!
		case .newsBlur:
			return NSColor(named: "newsblurColor")!
		case .theOldReader:
			return NSColor(named: "theoldreaderColor")!
		default:
			return NSColor.blue
		}
	}
	#else
	func iconColor() -> UIColor {
		switch self {
		case .onMyMac:
			return UIColor(named: "localColor")!
		case .bazQux:
			return UIColor(named: "bazquxColor")!
		case .cloudKit:
			return UIColor(named: "cloudkitColor")!
		case .feedWrangler:
			return UIColor(named: "feedwranglerColor")!
		case .feedbin:
			return UIColor(named: "feedbinColor")!
		case .feedly:
			return UIColor(named: "feedlyColor")!
		case .freshRSS:
			return UIColor(named: "freshRSSColor")!
		case .inoreader:
			return UIColor(named: "inoreaderColor")!
		case .newsBlur:
			return UIColor(named: "newsblurColor")!
		case .theOldReader:
			return UIColor(named: "theoldreaderColor")!
		default:
			return UIColor.blue
		}
	}
	#endif
	
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
		default:
			return ""
		}
		
		
		
		
		
	}

}
