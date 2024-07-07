//
//  CalendarExtensionsTests.swift
//  
//
//  Created by Brent Simmons on 5/18/24.
//

import XCTest

final class CalendarExtensionsTests: XCTestCase {

	// MARK: - Test dateIsToday

	func testDateIsToday() {

		var date = Date()
		// The below could fail if midnight hits between the above line and the following line! This will probably never happen, but if it does, check to see if this was run at midnight.
		XCTAssertTrue(Calendar.dateIsToday(date))

		date = Date.distantPast
		XCTAssertFalse(Calendar.dateIsToday(date))

		date = Date.distantFuture
		XCTAssertFalse(Calendar.dateIsToday(date))

		date = Date().byAdding(days: 14)
		XCTAssertFalse(Calendar.dateIsToday(date))

		date = Date().bySubtracting(days: 67)
		XCTAssertFalse(Calendar.dateIsToday(date))

		let calendar = Calendar.current
		let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
		XCTAssertFalse(Calendar.dateIsToday(yesterday))

		let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
		XCTAssertFalse(Calendar.dateIsToday(tomorrow))
	}
 }
