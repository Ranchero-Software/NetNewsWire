//
//  Calendar+RSCore.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-01.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Calendar {

	/// A cached `.autoupdatingCurrent` for performance.
	static let cached: Calendar = .autoupdatingCurrent

	/// Determine whether a date is in today.
	///
	/// - Parameter date: The specified date.
	///
	/// - Returns: `true` if `date` is in today; `false` otherwise.
	static func dateIsToday(_ date: Date) -> Bool {
		return cached.isDateInToday(date)
	}
}
