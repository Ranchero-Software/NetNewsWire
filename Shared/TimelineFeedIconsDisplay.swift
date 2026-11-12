//
//  TimelineFeedIconsDisplay.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/26/26.
//

import Foundation

extension Notification.Name {
	static let timelineFeedIconsDisplayDidChange = Notification.Name("TimelineFeedIconsDisplayDidChangeNotification")
}

/// When the timeline shows feed icons.
enum TimelineFeedIconsDisplay: Int, CaseIterable, CustomStringConvertible {
	case automatic = 0 // Folders, smart feeds, and single feeds whose articles have author avatars
	case always = 1
	case never = 2

	var description: String {
		switch self {
		case .automatic:
			NSLocalizedString("Automatic", comment: "Automatic")
		case .always:
			NSLocalizedString("Always", comment: "Always")
		case .never:
			NSLocalizedString("Never", comment: "Never")
		}
	}

	/// Explains a choice whose description doesn’t say what it does.
	var subtitle: String? {
		switch self {
		case .automatic:
			NSLocalizedString("Folders, smart feeds, and authors with avatars", comment: "Feed Icons setting: explains when Automatic shows feed icons")
		case .always, .never:
			nil
		}
	}
}
