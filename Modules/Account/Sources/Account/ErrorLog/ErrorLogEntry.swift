//
//  ErrorLogEntry.swift
//  Account
//
//  Created by Brent Simmons on 3/11/26.
//

import Foundation
import RSDatabase

public struct ErrorLogEntry: Sendable {

	public let id: Int64
	public let date: Date
	public let accountName: String
	public let accountType: Int
	public let errorMessage: String

	public init(id: Int64, date: Date, accountName: String, accountType: Int, errorMessage: String) {
		self.id = id
		self.date = date
		self.accountName = accountName
		self.accountType = accountType
		self.errorMessage = errorMessage
	}

	struct DatabaseKey {
		static let id = "id"
		static let date = "date"
		static let accountName = "accountName"
		static let accountType = "accountType"
		static let errorMessage = "errorMessage"
	}

	func databaseDictionary() -> DatabaseDictionary {
		[
			DatabaseKey.date: date.timeIntervalSince1970,
			DatabaseKey.accountName: accountName,
			DatabaseKey.accountType: accountType,
			DatabaseKey.errorMessage: errorMessage
		]
	}
}
