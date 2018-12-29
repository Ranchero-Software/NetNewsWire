//
//  CrashReportWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa

final class CrashReportWindowController: NSWindowController {

	@IBOutlet var textView: NSTextView! {
		didSet {
			textView.font = NSFont.userFixedPitchFont(ofSize: 0.0)
			textView.textContainerInset = NSSize(width: 5.0, height: 5.0)
			textView.string = crashLog.content
		}
	}

	@IBOutlet var sendCrashLogButton: NSButton!
	@IBOutlet var dontSendButton: NSButton!

	var testing = false // If true, crashLog won’t actually be sent.
	
	private var crashLog: CrashLog!

	private var didSendCrashLog = false {
		didSet {
			sendCrashLogButton.isEnabled = !didSendCrashLog
			dontSendButton.isEnabled = !didSendCrashLog
		}
	}

	convenience init(crashLog: CrashLog) {
		self.init(windowNibName: "CrashReporterWindow")
		self.crashLog = crashLog
	}

	override func showWindow(_ sender: Any?) {
		super.showWindow(sender)
		window!.center()
		window!.makeKeyAndOrderFront(sender)
	}

	// MARK: - Actions

	@IBAction func sendCrashReport(_ sender: Any?) {
		guard !didSendCrashLog else {
			return
		}
		didSendCrashLog = true
		if !testing {
			CrashReporter.sendCrashLog(crashLog)
		}
		showThanksSheet()
	}

	@IBAction func dontSendCrashReport(_ sender: Any?) {
		close()
	}
}

private extension CrashReportWindowController {

	func showThanksSheet() {
		guard let window = window else {
			return
		}

		let alert = NSAlert()
		alert.alertStyle = .informational
		alert.messageText = NSLocalizedString("Crash Report Sent", comment: "Crash Report Window")
		alert.informativeText = NSLocalizedString("Thank you! This helps us to know about crashing bugs, so we can fix them.", comment: "Crash Report Window")
		alert.beginSheetModal(for: window)
	}
}
