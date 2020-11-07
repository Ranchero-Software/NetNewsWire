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
	
	#if os(macOS)
	var fontSize: Int {
		switch self {
		case .small:
			return 14
		case .medium:
			return 16
		case .large:
			return 18
		case .xlarge:
			return 20
		case .xxlarge:
			return 22
		}
	}
	#endif
	
	var id: String { description() }
	
	func description() -> String {
		switch self {
		case .small:
			return NSLocalizedString("Small", comment: "Small")
		case .medium:
			return NSLocalizedString("Medium", comment: "Medium")
		case .large:
			return NSLocalizedString("Large", comment: "Large")
		case .xlarge:
			return NSLocalizedString("X-Large", comment: "X-Large")
		case .xxlarge:
			return NSLocalizedString("XX-Large", comment: "XX-Large")
		}
	}
	
}
