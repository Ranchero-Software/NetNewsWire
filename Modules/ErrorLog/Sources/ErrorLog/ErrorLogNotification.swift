//
//  ErrorLogNotification.swift
//  ErrorLog
//
//  Created by Brent Simmons on 3/12/26.
//

import Foundation

public extension Notification.Name {

	/// Posted when any component encounters an error that should be logged.
	/// UserInfo keys are defined in ErrorLogUserInfoKey.
	static let appDidEncounterError = Notification.Name(rawValue: "AppDidEncounterErrorNotification")
}

public struct ErrorLogUserInfoKey {

	public static let sourceName = "sourceName"
	public static let sourceID = "sourceID" // 0-99 are AccountType raw values. 100 and greater are for other components.
	public static let operation = "operation"
	public static let fileName = "fileName"
	public static let functionName = "functionName"
	public static let lineNumber = "lineNumber"
	public static let errorMessage = "errorMessage"

	public static func userInfo(sourceName: String, sourceID: Int, operation: String, errorMessage: String, fileName: String = #fileID, functionName: String = #function, lineNumber: Int = #line) -> [String: Any] {
		[
			Self.sourceName: sourceName,
			Self.sourceID: sourceID,
			Self.operation: operation,
			Self.fileName: fileName,
			Self.functionName: functionName,
			Self.lineNumber: lineNumber,
			Self.errorMessage: errorMessage
		]
	}
}

public extension ErrorLogEntry {

	/// Build an entry from an `.appDidEncounterError` notification. Returns nil if any required
	/// key is missing. The id is 0 — the entry has not yet been persisted.
	init?(notification: Notification) {
		guard let userInfo = notification.userInfo,
			  let errorMessage = userInfo[ErrorLogUserInfoKey.errorMessage] as? String,
			  let sourceName = userInfo[ErrorLogUserInfoKey.sourceName] as? String,
			  let sourceID = userInfo[ErrorLogUserInfoKey.sourceID] as? Int else {
			return nil
		}
		self.init(
			id: 0,
			date: Date(),
			sourceName: sourceName,
			sourceID: sourceID,
			operation: userInfo[ErrorLogUserInfoKey.operation] as? String ?? "",
			fileName: userInfo[ErrorLogUserInfoKey.fileName] as? String ?? "",
			functionName: userInfo[ErrorLogUserInfoKey.functionName] as? String ?? "",
			lineNumber: userInfo[ErrorLogUserInfoKey.lineNumber] as? Int ?? 0,
			errorMessage: errorMessage
		)
	}
}
