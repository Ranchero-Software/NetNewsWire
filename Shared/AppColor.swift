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
	static var tickMark = color("tickMarkColor")
#endif
}

// MARK: - Private

private extension AppColor {

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
