//
//  TimelineTextSize.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/7/26.
//

import Foundation

extension Notification.Name {
	static let timelineTextSizeDidChange = Notification.Name("TimelineTextSizeDidChangeNotification")
}

/// Text size in the timeline.
enum TimelineTextSize: Int, CaseIterable, CustomStringConvertible {
	case small = 1
	case medium = 2
	case large = 3
	case extraLarge = 4
	case extraExtraLarge = 5

	var description: String {
		switch self {
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
