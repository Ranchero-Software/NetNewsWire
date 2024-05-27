//
//  IndeterminateProgressWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/28/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public func runIndeterminateProgressWithMessage(_ message: String) {

	IndeterminateProgressController.beginProgressWithMessage(message)
}

public func stopIndeterminateProgress() {

	IndeterminateProgressController.endProgress()
}

private final class IndeterminateProgressController {

	static var windowController: IndeterminateProgressWindowController?
	static var runningProgressWindow = false
	static var modalSession: NSApplication.ModalSession?

	static func beginProgressWithMessage(_ message: String) {

		if runningProgressWindow {
			assertionFailure("Expected !runningProgressWindow.")
			endProgress()
		}

		runningProgressWindow = true
		windowController = IndeterminateProgressWindowController(message: message)

		assert(modalSession == nil)
		modalSession = NSApplication.shared.beginModalSession(for: windowController!.window!)
		NSApplication.shared.runModalSession(modalSession!)
	}

	static func endProgress() {

		if !runningProgressWindow {
			assertionFailure("Expected runningProgressWindow.")
			return
		}

		runningProgressWindow = false
		if let modalSession {
			NSApplication.shared.endModalSession(modalSession)
		} else {
			assertionFailure("endProgress called without a modalSession.")
		}

		windowController?.close()
		windowController = nil
		modalSession = nil
	}
}

private final class IndeterminateProgressWindowController: NSWindowController {

	@IBOutlet var messageLabel: NSTextField!
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@objc dynamic var message = ""

	convenience init(message: String) {
        self.init(window: nil)
		self.message = message
        Bundle.module.loadNibNamed("IndeterminateProgressWindow", owner: self, topLevelObjects: nil)
	}

	override func windowDidLoad() {

		progressIndicator.startAnimation(self)
	}
}
#endif


