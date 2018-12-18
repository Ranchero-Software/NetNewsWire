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


struct CrashReporter {

	/// Look in ~/Library/Logs/DiagnosticReports/ for a new crash log for this app.
	/// Show a crash log catcher window if found.
	static func check(appName: String) throws {
		let folder = ("~/Library/Logs/DiagnosticReports/" as NSString).expandingTildeInPath
		let crashSuffix = ".crash"
		let lowerAppName = appName.lowercased()
		let filenames = try FileManager.default.contentsOfDirectory(atPath: folder)

		var mostRecentFilePath: String? = nil
		var mostRecentFileDate = NSDate.distantPast
		for filename in filenames {
			if !filename.lowercased().hasPrefix(lowerAppName) {
				continue
			}
			if !filename.hasSuffix(crashSuffix) {
				continue
			}

			let path = (folder as NSString).appendingPathComponent(filename)
			let fileAttributes = try FileManager.default.attributesOfItem(atPath: path)
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
		guard let crashLog = try? NSString(contentsOfFile: crashLogPath, usedEncoding: nil) else {
			return
		}

		// Check to see if we’ve already reported this crash log. This should be common.
		let hashOfLog = crashLog.rs_md5Hash()
		let hashOfLastReportedCrashLogKey = "hashOfLastReportedCrashLog"
		if let lastLogHash = UserDefaults.standard.string(forKey: hashOfLastReportedCrashLogKey) {
			if hashOfLog == lastLogHash {
				return // Don’t report this crash log again.
			}
		}
		UserDefaults.standard.set(hashOfLog, forKey: hashOfLastReportedCrashLogKey)



	}
}


