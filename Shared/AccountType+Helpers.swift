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

	// MARK: - Log Colors

	#if os(macOS)
	var logColor: NSColor {
		switch self {
		case .onMyMac:
			return .onMyMacLogColor
		case .cloudKit:
			return .systemPurple
		case .feedly:
			return .systemGreen
		case .feedbin:
			return .systemBlue
		case .newsBlur:
			return .systemOrange
		case .freshRSS:
			return .systemTeal
		case .inoreader:
			return .systemBrown
		case .bazQux:
			return .systemIndigo
		case .theOldReader:
			return .systemPink
		}
	}
	#else
	var logColor: Color {
		switch self {
		case .onMyMac:
			return .secondary
		case .cloudKit:
			return .purple
		case .feedly:
			return .green
		case .feedbin:
			return .blue
		case .newsBlur:
			return .orange
		case .freshRSS:
			return .teal
		case .inoreader:
			return .brown
		case .bazQux:
			return .indigo
		case .theOldReader:
			return .pink
		}
	}
	#endif

	// MARK: - SwiftUI Images
	@MainActor func image() -> Image {
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

#if os(macOS)
extension NSColor {

	private static let onMyMacLogLightColor = NSColor(red: 0x4A / 255.0, green: 0x55 / 255.0, blue: 0x60 / 255.0, alpha: 1.0)
	private static let onMyMacLogDarkColor = NSColor(red: 0xB0 / 255.0, green: 0xBA / 255.0, blue: 0xC4 / 255.0, alpha: 1.0)

	/// Activity Log color for the On My Mac account. Slate gray — darker on light backgrounds, lighter on dark.
	static let onMyMacLogColor = NSColor(name: "onMyMacLogColor") { appearance in
		let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
		return isDark ? onMyMacLogDarkColor : onMyMacLogLightColor
	}
}
#endif
