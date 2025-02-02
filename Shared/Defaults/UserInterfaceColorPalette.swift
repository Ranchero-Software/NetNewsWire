//
//  UserInterfaceColorPalette.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/26/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

#if os(iOS)

import Foundation
import UIKit

enum UserInterfaceColorPalette: Int, CustomStringConvertible, CaseIterable {

	case automatic = 0
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

	var uiUserInterfaceStyle: UIUserInterfaceStyle {
		switch self {
		case .automatic:
			.unspecified
		case .light:
			.light
		case .dark:
			.dark
		}
	}
}

#endif
