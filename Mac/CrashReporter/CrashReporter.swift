//
//  CrashReporter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation
import RSWeb

// Based originally on Uli Kusterer's UKCrashReporter: http://www.zathras.de/angelweb/blog-ukcrashreporter-oh-one.htm
// Then based on the crash reporter included in NetNewsWire 3 and NetNewsWire Lite 4.
// Displays a window that shows the crash log — gives the user the chance to add data.
// (Or just decide not to send it.)
// This code is not included in the MAS build.
// At some point this code should probably move into RSCore, so Rainier and any other
// future apps can use it.


struct CrashLog {

	let path: String
	let modificationDate: Date
	let content: String
	let contentHash: String

	init?(path: String, modificationDate: Date) {
		guard let s = try? NSString(contentsOfFile: path, usedEncoding: nil) as String, !s.isEmpty else {
			return nil
		}
		self.content = s
		self.contentHash = s.md5String
		self.path = path
		self.modificationDate = modificationDate
	}
}

struct CrashReporter {

	struct DefaultsKey {
		static let lastSeenCrashLogDateKey = "LastSeenCrashLogDate"
		static let hashOfLastSeenCrashLogKey = "LastSeenCrashLogHash"
		static let sendCrashLogsAutomaticallyKey = "SendCrashLogsAutomatically"
	}

	private static var crashReportWindowController: CrashReportWindowController?

	/// Look in ~/Library/Logs/DiagnosticReports/ for a new crash log for this app.
	/// Show a crash log reporter window if found.
	static func check(appName: String) {
		let folder = ("~/Library/Logs/DiagnosticReports/" as NSString).expandingTildeInPath
		guard let filenames = try? FileManager.default.contentsOfDirectory(atPath: folder) else {
			return
		}

		let crashSuffix = ".crash"
		let lowerAppName = appName.lowercased()
		let lastSeenCrashLogDate: Date = {
			let lastSeenCrashLogDouble = UserDefaults.standard.double(forKey: DefaultsKey.lastSeenCrashLogDateKey)
			return Date(timeIntervalSince1970: lastSeenCrashLogDouble)
		}()

		var mostRecentFilePath: String? = nil
		var mostRecentFileDate = Date.distantPast
		for filename in filenames {
			if !filename.lowercased().hasPrefix(lowerAppName) || !filename.hasSuffix(crashSuffix) {
				continue
			}

			let path = (folder as NSString).appendingPathComponent(filename)
			let fileAttributes = (try? FileManager.default.attributesOfItem(atPath: path)) ?? [FileAttributeKey: Any]()
			if let fileModificationDate = fileAttributes[.modificationDate] as? Date {
				if fileModificationDate > lastSeenCrashLogDate && fileModificationDate > mostRecentFileDate { // Ignore if previously seen
					mostRecentFileDate = fileModificationDate
					mostRecentFilePath = path
				}
			}
		}

		guard let crashLogPath = mostRecentFilePath, let crashLog = CrashLog(path: crashLogPath, modificationDate: mostRecentFileDate) else {
			return
		}

		if hasSeen(crashLog) {
			return
		}
		remember(crashLog)

		if shouldSendCrashLogsAutomatically() {
			sendCrashLogText(crashLog.content)
		}
		else {
			runCrashReporterWindow(crashLog)
		}
	}

	static func sendCrashLogText(_ crashLogText: String) {
		var request = URLRequest(url: URL(string: "https://ranchero.com/netnewswire/crashreportcatcher.php")!)
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

	static func runCrashReporterWindow(_ crashLog: CrashLog) {
		crashReportWindowController = CrashReportWindowController(crashLogText: crashLog.content)
		crashReportWindowController!.showWindow(self)
	}
}

private extension CrashReporter {

	static func hasSeen(_ crashLog: CrashLog) -> Bool {
		// No need to compare dates, because that’s done in the file loop.
		// Check to see if we’ve already reported this exact crash log.
		guard let hashOfLastSeenCrashLog = UserDefaults.standard.string(forKey: DefaultsKey.hashOfLastSeenCrashLogKey) else {
			return false
		}
		return hashOfLastSeenCrashLog == crashLog.contentHash
	}

	static func remember(_ crashLog: CrashLog) {
		// Save the modification date and hash, so we don’t send duplicates.
		UserDefaults.standard.set(crashLog.contentHash, forKey: DefaultsKey.hashOfLastSeenCrashLogKey)
		UserDefaults.standard.set(crashLog.modificationDate.timeIntervalSince1970, forKey: DefaultsKey.lastSeenCrashLogDateKey)
	}

	static func shouldSendCrashLogsAutomatically() -> Bool {
		return UserDefaults.standard.bool(forKey: DefaultsKey.sendCrashLogsAutomaticallyKey)
	}
}
