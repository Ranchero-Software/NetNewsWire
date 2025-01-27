//
//  ArticleTextSize.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/26/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

enum ArticleTextSize: Int, CaseIterable, Identifiable {
	case small = 1
	case medium = 2
	case large = 3
	case xlarge = 4
	case xxlarge = 5

	var id: String { description() }

	var cssClass: String {
		switch self {
		case .small:
			return "smallText"
		case .medium:
			return "mediumText"
		case .large:
			return "largeText"
		case .xlarge:
			return "xLargeText"
		case .xxlarge:
			return "xxLargeText"
		}
	}

	func description() -> String {
		switch self {
		case .small:
			return NSLocalizedString("Small", comment: "Small")
		case .medium:
			return NSLocalizedString("Medium", comment: "Medium")
		case .large:
			return NSLocalizedString("Large", comment: "Large")
		case .xlarge:
			return NSLocalizedString("Extra Large", comment: "X-Large")
		case .xxlarge:
			return NSLocalizedString("Extra Extra Large", comment: "XX-Large")
		}
	}
}
