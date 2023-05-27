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
			return NSLocalizedString("label.text.small", comment: "Small")
		case .medium:
			return NSLocalizedString("label.text.medium", comment: "Medium")
		case .large:
			return NSLocalizedString("label.text.large", comment: "Large")
		case .xlarge:
			return NSLocalizedString("label.text.extra-large", comment: "X-Large")
		case .xxlarge:
			return NSLocalizedString("label.text.extra-extra-large", comment: "XX-Large")
		}
	}
	
}
