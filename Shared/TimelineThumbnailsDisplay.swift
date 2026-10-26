//
//  TimelineThumbnailsDisplay.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/26/26.
//

import Foundation

extension Notification.Name {
	static let timelineThumbnailsDisplayDidChange = Notification.Name("TimelineThumbnailsDisplayDidChangeNotification")
}

/// How article thumbnails are shown in the timeline.
enum TimelineThumbnailsDisplay: Int, CaseIterable, CustomStringConvertible {
	case small = 0 // To the right of the text
	case large = 1 // Below the text, spanning the cell
	case none = 2

	var description: String {
		switch self {
		case .small:
			NSLocalizedString("Small", comment: "Small")
		case .large:
			NSLocalizedString("Large", comment: "Large")
		case .none:
			NSLocalizedString("None", comment: "None")
		}
	}
}
