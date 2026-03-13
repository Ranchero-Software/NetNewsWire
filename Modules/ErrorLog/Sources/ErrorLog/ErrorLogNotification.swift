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
	public static let errorMessage = "errorMessage"

	public static func userInfo(sourceName: String, sourceID: Int, errorMessage: String) -> [String: Any] {
		[
			Self.sourceName: sourceName,
			Self.sourceID: sourceID,
			Self.errorMessage: errorMessage
		]
	}
}
