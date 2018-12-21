//
//  CrashReporter.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/17/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

// Based originally on Uli Kusterer's UKCrashReporter: http://www.zathras.de/angelweb/blog-ukcrashreporter-oh-one.htm
// Then based on the crash reporter included in NetNewsWire 3 and NetNewsWire Lite 4.
// Displays a window that shows the crash log — gives the user the chance to add data.
// (Or just decide not to send it.)
// This code is not included in the MAS build.
// At some point this code should probably move into RSCore, so Rainier and any other
// future apps can use it.


class CrashReporter {

	static let shared = CrashReporter()

	private struct DefaultsKey {
		static let lastSeenCrashLogDateKey = "LastSeenCrashLogDate"
		static let hashOfLastSeenCrashLogKey = "LastSeenCrashLogHash"
		static let sendCrashLogsAutomaticallyKey = "SendCrashLogsAutomatically"
	}

	private var sendCrashLogsAutomatically: Bool {
		get {
			return UserDefaults.standard.bool(forKey: DefaultsKey.sendCrashLogsAutomaticallyKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: DefaultsKey.sendCrashLogsAutomaticallyKey)
		}
	}

	private var hashOfLastSeenCrashLog: String? {
		get {
			return UserDefaults.standard.string(forKey: DefaultsKey.hashOfLastSeenCrashLogKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: DefaultsKey.hashOfLastSeenCrashLogKey)
		}
	}

	private var lastSeenCrashLogDate: Date? {
		get {
			let lastSeenCrashLogDouble = UserDefaults.standard.double(forKey: DefaultsKey.lastSeenCrashLogDateKey)
			if lastSeenCrashLogDouble < 1.0 {
				return nil
			}
			return Date(timeIntervalSince1970: lastSeenCrashLogDouble)
		}
		set {
			UserDefaults.standard.set(newValue!.timeIntervalSince1970, forKey: DefaultsKey.hashOfLastSeenCrashLogKey)
		}
	}

	/// Look in ~/Library/Logs/DiagnosticReports/ for a new crash log for this app.
	/// Show a crash log catcher window if found.
	func check(appName: String) {
		let folder = ("~/Library/Logs/DiagnosticReports/" as NSString).expandingTildeInPath
		let crashSuffix = ".crash"
		let lowerAppName = appName.lowercased()

		var filenames = [String]()
		do {
			filenames = try FileManager.default.contentsOfDirectory(atPath: folder)
		}
		catch {
			return
		}

		var mostRecentFilePath: String? = nil
		var mostRecentFileDate = Date.distantPast
		for filename in filenames {
			if !filename.lowercased().hasPrefix(lowerAppName) {
				continue
			}
			if !filename.hasSuffix(crashSuffix) {
				continue
			}

			let path = (folder as NSString).appendingPathComponent(filename)
			var fileAttributes = [FileAttributeKey: Any]()
			do {
				fileAttributes = try FileManager.default.attributesOfItem(atPath: path)
			}
			catch {
				continue
			}
			if let fileModificationDate = fileAttributes[.modificationDate] as? Date {
				if fileModificationDate > mostRecentFileDate {
					mostRecentFileDate = fileModificationDate
					mostRecentFilePath = path
				}
			}
		}

		guard let crashLogPath = mostRecentFilePath else {
			return
		}

		if let lastSeenCrashLogDate = lastSeenCrashLogDate, lastSeenCrashLogDate >= mostRecentFileDate {
			return
		}

		guard let crashLog = try? NSString(contentsOfFile: crashLogPath, usedEncoding: nil) as String else {
			return
		}
		let hashOfFoundLog = crashLog.rs_md5Hash()

		// Check to see if we’ve already reported this crash log. Just in case date comparison fails.
		if let lastSeenHash = hashOfLastSeenCrashLog, lastSeenHash == hashOfFoundLog {
			return
		}
		hashOfLastSeenCrashLog = hashOfFoundLog
		lastSeenCrashLogDate = mostRecentFileDate

		// Run crash log window.
		if sendCrashLogsAutomatically {
			sendCrashLog(crashLog)
			return
		}
	}
}

private extension CrashReporter {

	func sendCrashLog(_ crashLog: String) {
		// TODO
	}
}
