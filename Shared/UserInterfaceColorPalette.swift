//
//  UserInterfaceColorPalette.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/6/26.
//

import Foundation

extension Notification.Name {
	static let userInterfaceColorPaletteDidUpdate = Notification.Name("UserInterfaceColorPaletteDidUpdateNotification")
}

/// Whether the app follows the system appearance or is forced to light or dark.
enum UserInterfaceColorPalette: Int, CustomStringConvertible, CaseIterable {
	case automatic = 0 // Follows the system
	case light = 1
	case dark = 2

	var description: String {
		switch self {
		case .automatic:
			NSLocalizedString("Automatic", comment: "Automatic")
		case .light:
			NSLocalizedString("Light", comment: "Light")
		case .dark:
			NSLocalizedString("Dark", comment: "Dark")
		}
	}
}
