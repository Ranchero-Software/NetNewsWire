//
//  SidebarTextSize.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/6/26.
//

import Foundation

extension Notification.Name {
	static let sidebarTextSizeDidChange = Notification.Name("SidebarTextSizeDidChangeNotification")
}

/// Text size in the sidebar.
enum SidebarTextSize: Int, CaseIterable, CustomStringConvertible {
	case system = 0
	case small = 1
	case medium = 2
	case large = 3
	case extraLarge = 4
	case extraExtraLarge = 5

	var description: String {
		switch self {
		case .system:
			NSLocalizedString("System", comment: "System")
		case .small:
			NSLocalizedString("Small", comment: "Small")
		case .medium:
			NSLocalizedString("Medium", comment: "Medium")
		case .large:
			NSLocalizedString("Large", comment: "Large")
		case .extraLarge:
			NSLocalizedString("Extra Large", comment: "X-Large")
		case .extraExtraLarge:
			NSLocalizedString("Extra Extra Large", comment: "XX-Large")
		}
	}
}
