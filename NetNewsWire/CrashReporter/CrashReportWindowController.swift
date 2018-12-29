//
//  CrashReportWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa

final class CrashReportWindowController: NSWindowController {

	private var crashLog: CrashLog!
	private static let windowName = "CrashReporterWindow"

	convenience init(crashLog: CrashLog) {
		self.init(windowNibName: CrashReportWindowController.windowName)
		self.crashLog = crashLog
	}

	@IBOutlet var textView: NSTextView! {
		didSet {
			textView.font = NSFont.userFixedPitchFont(ofSize: 0.0)
			textView.textContainerInset = NSSize(width: 5.0, height: 5.0)
			textView.string = crashLog.content
		}
	}

    override func windowDidLoad() {
        super.windowDidLoad()
		windowFrameAutosaveName = CrashReportWindowController.windowName
    }

	// MARK: - Actions

	@IBAction func sendCrashReport(_ sender: Any?) {
		CrashReporter.sendCrashLog(crashLog)
		// TODO: some kind of acknowledgement
	}

	@IBAction func cancel(_ sender: Any?) {
		close()
	}

	@IBAction func showPrivacyPolicy(_ sender: Any?) {
		Browser.open(AppConstants.privacyPolicyURL, inBackground: false)
	}
}

private extension CrashReportWindowController {

}
