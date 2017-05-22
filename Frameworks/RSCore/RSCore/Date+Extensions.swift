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
	
	public mutating func subtract(days: Int) {
		
		addTimeInterval(0.0 - timeIntervalWithDays(days))
	}

	public mutating func add(days: Int) {
		
		addTimeInterval(timeIntervalWithDays(days))
	}
}

private func timeIntervalWithDays(_ days: Int) -> TimeInterval {
	
	return TimeInterval(days * 24 * 60 * 60)
}
