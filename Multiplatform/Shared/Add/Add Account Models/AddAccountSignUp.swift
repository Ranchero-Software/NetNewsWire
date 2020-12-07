//
//  AddAccountSignUp.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 06/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
#if os(iOS)
import UIKit
#endif


/// Helper functions common to most account services.
protocol AddAccountSignUp {
	func presentSignUpOption(_ accountType: AccountType)
}


extension AddAccountSignUp {
	func presentSignUpOption(_ accountType: AccountType) {
		#if os(macOS)
		switch accountType {
		case .bazQux:
			NSWorkspace.shared.open(URL(string: "https://bazqux.com")!)
		case .feedbin:
			NSWorkspace.shared.open(URL(string: "https://feedbin.com/signup")!)
		case .feedly:
			NSWorkspace.shared.open(URL(string: "https://feedly.com")!)
		case .feedWrangler:
			NSWorkspace.shared.open(URL(string: "https://feedwrangler.net/users/new")!)
		case .freshRSS:
			NSWorkspace.shared.open(URL(string: "https://freshrss.org")!)
		case .inoreader:
			NSWorkspace.shared.open(URL(string: "https://www.inoreader.com")!)
		case .newsBlur:
			NSWorkspace.shared.open(URL(string: "https://newsblur.com")!)
		case .theOldReader:
			NSWorkspace.shared.open(URL(string: "https://theoldreader.com")!)
		default:
			return
		}
		#else
		switch accountType {
		case .bazQux:
			UIApplication.shared.open(URL(string: "https://bazqux.com")!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		case .feedbin:
			UIApplication.shared.open(URL(string: "https://feedbin.com/signup")!, options: [:], completionHandler: nil)
		case .feedly:
			UIApplication.shared.open(URL(string: "https://feedly.com")!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		case .feedWrangler:
			UIApplication.shared.open(URL(string: "https://feedwrangler.net/users/new")!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		case .freshRSS:
			UIApplication.shared.open(URL(string: "https://freshrss.org")!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		case .inoreader:
			UIApplication.shared.open(URL(string: "https://www.inoreader.com")!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		case .newsBlur:
			UIApplication.shared.open(URL(string: "https://newsblur.com")!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		case .theOldReader:
			UIApplication.shared.open(URL(string: "https://theoldreader.com")!, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly : false], completionHandler: nil)
		default:
			return
		}
		#endif
	}
}
