//
//  Date+Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 6/21/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Date {

	// Below are for rough use only — they don't use the calendar.

	func bySubtracting(days: Int) -> Date {
		return addingTimeInterval(0.0 - TimeInterval(days: days))
	}

	func bySubtracting(hours: Int) -> Date {
		return addingTimeInterval(0.0 - TimeInterval(hours: hours))
	}

	func byAdding(days: Int) -> Date {
		return addingTimeInterval(TimeInterval(days: days))
	}
}

public extension TimeInterval {

	init(days: Int) {
		self.init(days * 24 * 60 * 60)
	}

	init(hours: Int) {
		self.init(hours * 60 * 60)
	}
}
