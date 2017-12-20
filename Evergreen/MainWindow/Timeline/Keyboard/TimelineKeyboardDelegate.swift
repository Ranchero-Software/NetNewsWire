//
//  TimelineKeyboardDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import RSCore

// Doesn’t have any shortcuts of its own — they’re all in MainWindowKeyboardHandler.

@objc final class TimelineKeyboardDelegate: NSObject, KeyboardDelegate {

	@IBOutlet weak var timelineViewController: TimelineViewController?

	override init() {
		super.init()
	}
	
	func keydown(_ event: NSEvent, in view: NSView) -> Bool {

		return  MainWindowKeyboardHandler.shared.keydown(event, in: view)
	}
}
