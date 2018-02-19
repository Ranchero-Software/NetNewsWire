//
//  FeedListKeyboardDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/26/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

@objc final class FeedListTimelineKeyboardDelegate: NSObject, KeyboardDelegate {

	@IBOutlet weak var timelineViewController: TimelineViewController?

	func keydown(_ event: NSEvent, in view: NSView) -> Bool {

		// TODO
		return false
	}
}
