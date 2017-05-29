//
//  IndeterminateProgressWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

class IndeterminateProgressWindowController: NSWindowController {

	@IBOutlet var messageLabel: NSTextField!
	@IBOutlet var progressIndicator: NSProgressIndicator!
	dynamic var message = ""

	convenience init(message: String) {

		self.init(windowNibName: "IndeterminateProgressWindow")
		self.message = message
	}

	override func windowDidLoad() {

		progressIndicator.startAnimation(self)
	}
}

func runIndeterminateProgressWithMessage(_ message: String) {

	let windowController = IndeterminateProgressWindowController(message: message)
	NSApplication.shared().runModal(for: windowController.window!)
}

func stopIndeterminateProgress() {

	NSApplication.shared().stopModal()
}
