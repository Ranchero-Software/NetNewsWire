//
//  CrashReporter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation
import RSWeb
import CrashReporter

// Displays a window that shows the crash log — gives the user the chance to add data.
// (Or just decide not to send it.)
// This code is not included in the MAS build.
// At some point this code should probably move into RSCore, so Rainier and any other
// future apps can use it.

struct CrashReporter {

	struct DefaultsKey {
		static let sendCrashLogsAutomaticallyKey = "SendCrashLogsAutomatically"
	}

	private static var crashReportWindowController: CrashReportWindowController?

	/// Look in ~/Library/Logs/DiagnosticReports/ for a new crash log for this app.
	/// Show a crash log reporter window if found.
	static func check(crashReporter: PLCrashReporter) {
		guard crashReporter.hasPendingCrashReport(),
			  let crashData = crashReporter.loadPendingCrashReportData(),
			  let crashReport = try? PLCrashReport(data: crashData),
			  let crashLogText = PLCrashReportTextFormatter.stringValue(for: crashReport, with: PLCrashReportTextFormatiOS) else { return }

		if shouldSendCrashLogsAutomatically() {
			sendCrashLogText(crashLogText)
		} else {
			runCrashReporterWindow(crashLogText)
		}
		
		crashReporter.purgePendingCrashReport()
	}

	static func sendCrashLogText(_ crashLogText: String) {
		var request = URLRequest(url: URL(string: "https://services.netnewswire.com/reportCrash.php")!)
		request.httpMethod = HTTPMethod.post

		let boundary = "0xKhTmLbOuNdArY"

		let contentType = "multipart/form-data; boundary=\(boundary)"
		request.setValue(contentType, forHTTPHeaderField:HTTPRequestHeader.contentType)

		let formString = "--\(boundary)\r\nContent-Disposition: form-data; name=\"crashlog\"\r\n\r\n\(crashLogText)\r\n--\(boundary)--\r\n"
		let formData = formString.data(using: .utf8, allowLossyConversion: true)
		request.httpBody = formData

		download(request) { (_, _, _) in
			// Don’t care about the result.
		}
	}

	static func runCrashReporterWindow(_ crashLogText: String) {
		crashReportWindowController = CrashReportWindowController(crashLogText: crashLogText)
		crashReportWindowController!.showWindow(self)
	}
}

private extension CrashReporter {

	static func shouldSendCrashLogsAutomatically() -> Bool {
		return UserDefaults.standard.bool(forKey: DefaultsKey.sendCrashLogsAutomaticallyKey)
	}
}
