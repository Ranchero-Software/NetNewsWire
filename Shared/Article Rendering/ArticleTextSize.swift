//
//  ArticleTextSize.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 11/3/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
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
			return NSLocalizedString("ACCESSIBILITY_S", comment: "Small")
		case .medium:
			return NSLocalizedString("ACCESSIBILITY_M", comment: "Medium")
		case .large:
			return NSLocalizedString("ACCESSIBILITY_L", comment: "Large")
		case .xlarge:
			return NSLocalizedString("ACCESSIBILITY_XL", comment: "X-Large")
		case .xxlarge:
			return NSLocalizedString("ACCESSIBILITY_XXL", comment: "XX-Large")
		}
	}
	
}
