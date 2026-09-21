//
//  TimelineLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/19/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import Foundation

/// Standard: one custom-drawn column, article view to the right.
/// Column: multi-column table with a header, article view below, like Mail’s Use Column Layout.
enum TimelineLayout {
	case standard
	case column
}

extension AppDefaults {

	var timelineLayout: TimelineLayout {
		useColumnLayout ? .column : .standard
	}
}
