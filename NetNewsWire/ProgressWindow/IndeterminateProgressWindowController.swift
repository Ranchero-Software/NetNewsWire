//
//  IndeterminateProgressWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

func runIndeterminateProgressWithMessage(_ message: String) {

	IndeterminateProgressController.beginProgressWithMessage(message)
}

func stopIndeterminateProgress() {

	IndeterminateProgressController.endProgress()
}

private final class IndeterminateProgressController {

	static var windowController: IndeterminateProgressWindowController?
	static var runningProgressWindow = false

	static func beginProgressWithMessage(_ message: String) {

		if runningProgressWindow {
			assertionFailure("Expected !runningProgressWindow.")
			endProgress()
		}

		runningProgressWindow = true
		windowController = IndeterminateProgressWindowController(message: message)
		NSApplication.shared.runModal(for: windowController!.window!)
	}

	static func endProgress() {

		if !runningProgressWindow {
			assertionFailure("Expected runningProgressWindow.")
			return
		}

		runningProgressWindow = false
		NSApplication.shared.stopModal()
		windowController?.close()
		windowController = nil
	}
}

private final class IndeterminateProgressWindowController: NSWindowController {

	@IBOutlet var messageLabel: NSTextField!
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@objc dynamic var message = ""

	convenience init(message: String) {

		self.init(windowNibName: NSNib.Name("IndeterminateProgressWindow"))
		self.message = message
	}

	override func windowDidLoad() {

		progressIndicator.startAnimation(self)
	}
}



