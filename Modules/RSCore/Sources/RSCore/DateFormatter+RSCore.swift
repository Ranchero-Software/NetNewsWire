//
//  DateFormatter+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 6/6/26.
//

import Foundation

public extension DateFormatter {

	/// Fixed-format log timestamp: `yyyy-MM-dd HH:mm:ss`, POSIX locale.
	static let logTimestamp: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		formatter.locale = Locale(identifier: "en_US_POSIX")
		return formatter
	}()
}
