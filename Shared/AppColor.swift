//
//  AppColor.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/27/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct AppColor {

	static var accent = color(isMac ? "AccentColor" : "primaryAccentColor")
	static var star = color(isMac ? "StarColor" : "starColor")
}

// MARK: - Mac

extension AppColor {

#if os(macOS)
	static var iconDarkBackground = color("iconDarkBackgroundColor")
	static var iconLightBackground = color("iconLightBackgroundColor")
	static var timelineSeparator = color("timelineSeparatorColor")
#endif
}

// MARK: - iOS

extension AppColor {

#if os(iOS)
	static var controlBackground = color("controlBackgroundColor")
	static var fullScreenBackground = color("fullScreenBackgroundColor")
	static var iconBackground = color("iconBackgroundColor")
	static var secondaryAccent = color("secondaryAccentColor")
	static var sectionHeader = color("sectionHeaderColor")
	static var tickMark = color("tickMarkColor")
	static var vibrantText = color("vibrantTextColor")
#endif
}

// MARK: - Private

private extension AppColor {

#if os(macOS)
	static var isMac = true
	static var isiOS = false
#elseif os(iOS)
	static var isMac = false
	static var isiOS = true
#endif

#if os(macOS)
	static func color(_ name: String) -> NSColor {
		NSColor(named: name)!
	}

#elseif os(iOS)
	static func color(_ name: String) -> UIColor {
		UIColor(named: name)!
	}
#endif
}
