//
//  UserInterfaceColorPalette.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/26/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

enum UserInterfaceColorPalette: Int, CustomStringConvertible, CaseIterable {
	case automatic = 0
	case light = 1
	case dark = 2

	var description: String {
		switch self {
		case .automatic:
			return NSLocalizedString("Automatic", comment: "Automatic")
		case .light:
			return NSLocalizedString("Light", comment: "Light")
		case .dark:
			return NSLocalizedString("Dark", comment: "Dark")
		}
	}
}
