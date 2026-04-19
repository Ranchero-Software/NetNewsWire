//
//  DateParserTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation
import XCTest
@testable import RSParser

final class DateParserTests: XCTestCase {

	// MARK: - Helpers

	static func dateWithValues(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int, _ milliseconds: Int = 0) -> Date {
		var dc = DateComponents()
		dc.calendar = Calendar.current
		dc.timeZone = TimeZone(secondsFromGMT: 0)
		dc.year = year
		dc.month = month
		dc.day = day
		dc.hour = hour
		dc.minute = minute
		dc.second = second
		dc.nanosecond = milliseconds * 1_000_000
		return dc.date!
	}

	/// Run both entry points against `input` and check that each matches `expected` AND
	/// that they agree with each other. `accuracy > 0` allows sub-second tolerance for
	/// millisecond-precision inputs.
	private func assertParsedDate(_ input: String,
	                              _ expected: Date,
	                              accuracy: TimeInterval = 0,
	                              file: StaticString = #filePath,
	                              line: UInt = #line) {
		let fromString = DateParser.date(from: input)
		let fromBytes = DateParser.date(bytes: ArraySlice(Array(input.utf8)))

		XCTAssertNotNil(fromString, "date(from:) returned nil for \(input)", file: file, line: line)
		XCTAssertNotNil(fromBytes, "date(bytes:) returned nil for \(input)", file: file, line: line)
		guard let fromString, let fromBytes else {
			return
		}

		if accuracy > 0 {
			XCTAssertEqual(fromString.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: accuracy, "date(from:) mismatch for \(input)", file: file, line: line)
			XCTAssertEqual(fromBytes.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: accuracy, "date(bytes:) mismatch for \(input)", file: file, line: line)
		} else {
			XCTAssertEqual(fromString, expected, "date(from:) mismatch for \(input)", file: file, line: line)
			XCTAssertEqual(fromBytes, expected, "date(bytes:) mismatch for \(input)", file: file, line: line)
		}
		XCTAssertEqual(fromString, fromBytes, "String and bytes paths disagreed for \(input)", file: file, line: line)
	}

	private func assertNilResult(_ input: String,
	                             file: StaticString = #filePath,
	                             line: UInt = #line) {
		XCTAssertNil(DateParser.date(from: input), "expected nil for \(input.debugDescription)", file: file, line: line)
		let bytes = ArraySlice(Array(input.utf8))
		XCTAssertNil(DateParser.date(bytes: bytes), "expected nil for bytes of \(input.debugDescription)", file: file, line: line)
	}

	// MARK: - Format: pubDate (RFC 822)

	func testPubDateStandardForms() {
		let expected = Self.dateWithValues(2010, 5, 28, 21, 3, 38)
		assertParsedDate("Fri, 28 May 2010 21:03:38 GMT", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 +0000", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 -0000", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 +00:00", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 -00:00", expected)
	}

	func testPubDateWithoutWeekday() {
		assertParsedDate("21 May 2010 21:22:53 GMT",
		                 Self.dateWithValues(2010, 5, 21, 21, 22, 53))
	}

	func testPubDateWithoutSeconds() {
		assertParsedDate("Fri, 28 May 2010 21:03 GMT",
		                 Self.dateWithValues(2010, 5, 28, 21, 3, 0))
		assertParsedDate("30 Apr 2010 5:00 PDT",
		                 Self.dateWithValues(2010, 4, 30, 12, 0, 0))
	}

	// MARK: - Format: W3C / ISO 8601

	func testW3CStandardForms() {
		let expected = Self.dateWithValues(2010, 5, 28, 21, 3, 38)
		assertParsedDate("2010-05-28T21:03:38Z", expected)
		assertParsedDate("2010-05-28T21:03:38+00:00", expected)
		assertParsedDate("2010-05-28T21:03:38-00:00", expected)
		assertParsedDate("2010-05-28T21:03:38+0000", expected)
		assertParsedDate("2010-05-28T21:03:38-0000", expected)
	}

	func testW3CMissingTSeparator() {
		// Atom feeds in the wild sometimes use a space where the spec wants `T`.
		assertParsedDate("2010-11-17 08:40:07-05:00",
		                 Self.dateWithValues(2010, 11, 17, 13, 40, 7))
	}

	func testW3CWithOffset() {
		assertParsedDate("2010-11-17T08:40:07-05:00",
		                 Self.dateWithValues(2010, 11, 17, 13, 40, 7))
		assertParsedDate("2010-07-13T17:06:40+00:00",
		                 Self.dateWithValues(2010, 7, 13, 17, 6, 40))
	}

	// MARK: - Time zones: half-hour / 45-min / extremes

	func testHalfHourOffsets() {
		// India +05:30
		assertParsedDate("2010-05-28T21:03:38+05:30",
		                 Self.dateWithValues(2010, 5, 28, 15, 33, 38))
		// ACST +09:30
		assertParsedDate("2010-05-28T21:03:38+09:30",
		                 Self.dateWithValues(2010, 5, 28, 11, 33, 38))
		// NDT -02:30
		assertParsedDate("2010-05-28T21:03:38-02:30",
		                 Self.dateWithValues(2010, 5, 28, 23, 33, 38))
	}

	func testFortyFiveMinuteOffsets() {
		// Nepal +05:45
		assertParsedDate("2010-05-28T21:03:38+05:45",
		                 Self.dateWithValues(2010, 5, 28, 15, 18, 38))
		// Chatham +12:45
		assertParsedDate("2010-05-28T21:03:38+12:45",
		                 Self.dateWithValues(2010, 5, 28, 8, 18, 38))
	}

	func testExtremeNumericOffsets() {
		// Kiribati LINT: +14:00
		assertParsedDate("2010-05-28T21:03:38+14:00",
		                 Self.dateWithValues(2010, 5, 28, 7, 3, 38))
		// BIT: -12:00
		assertParsedDate("2010-05-28T21:03:38-12:00",
		                 Self.dateWithValues(2010, 5, 29, 9, 3, 38))
	}

	// MARK: - Time zones: abbreviations

	func testTimeZoneAbbreviations() {
		// GMT / UTC / Z all map to offset 0 via short-circuit (not the dict).
		assertParsedDate("Wed, 23 Jun 2010 03:43:50 Z",
		                 Self.dateWithValues(2010, 6, 23, 3, 43, 50))
		// Dict-lookup path: abbreviations across continents.
		assertParsedDate("Wed, 09 Jun 2010 00:00 EST",
		                 Self.dateWithValues(2010, 6, 9, 5, 0, 0))
		// JST +9
		assertParsedDate("Wed, 09 Jun 2010 09:00:00 JST",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
		// CET +1
		assertParsedDate("Wed, 09 Jun 2010 01:00:00 CET",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
		// IST (Israel Standard Time in the table is +2; India's +5:30 IST collides, but the
		// table resolves to +2 — that's the documented behavior).
		assertParsedDate("Wed, 09 Jun 2010 02:00:00 IST",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
		// AEST +10
		assertParsedDate("Wed, 09 Jun 2010 10:00:00 AEST",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
	}

	func testTimeZoneLowercaseZ() {
		// Seen in the wild: lowercase `z` — the parser lowercases before comparing.
		assertParsedDate("2010-05-28T21:03:38z",
		                 Self.dateWithValues(2010, 5, 28, 21, 3, 38))
	}

	func testUnknownTimeZoneAbbreviation() {
		// Liberal mode: unknown abbreviation falls back to 0 offset.
		assertParsedDate("Fri, 28 May 2010 21:03:38 XYZ",
		                 Self.dateWithValues(2010, 5, 28, 21, 3, 38))
	}

	// MARK: - Months

	func testAllTwelveMonths() {
		let cases: [(String, Int)] = [
			("Jan", 1), ("Feb", 2), ("Mar", 3), ("Apr", 4),
			("May", 5), ("Jun", 6), ("Jul", 7), ("Aug", 8),
			("Sep", 9), ("Oct", 10), ("Nov", 11), ("Dec", 12)
		]
		for (monthName, month) in cases {
			let input = "15 \(monthName) 2020 12:00:00 GMT"
			assertParsedDate(input, Self.dateWithValues(2020, month, 15, 12, 0, 0))
		}
	}

	func testCaseInsensitiveMonthNames() {
		let expected = Self.dateWithValues(2020, 1, 15, 12, 0, 0)
		assertParsedDate("15 Jan 2020 12:00:00 GMT", expected)
		assertParsedDate("15 jan 2020 12:00:00 GMT", expected)
		assertParsedDate("15 JAN 2020 12:00:00 GMT", expected)
		assertParsedDate("15 jAN 2020 12:00:00 GMT", expected)
	}

	// MARK: - Years

	func testTwoDigitYear() {
		// https://github.com/Ranchero-Software/NetNewsWire/issues/5244
		assertParsedDate("Sun, 12 Apr 26 17:24:19 +0000",
		                 Self.dateWithValues(2026, 4, 12, 17, 24, 19))
		assertParsedDate("12 Apr 26 17:24:19 +0000",
		                 Self.dateWithValues(2026, 4, 12, 17, 24, 19))
		assertParsedDate("Fri, 28 May 99 21:03:38 +0000",
		                 Self.dateWithValues(2099, 5, 28, 21, 3, 38))
		assertParsedDate("01 Jan 00 00:00:00 +0000",
		                 Self.dateWithValues(2000, 1, 1, 0, 0, 0))
	}

	func testEpochBoundary() {
		// 1970-01-01T00:00:00Z is timeIntervalSince1970 == 0.
		let epoch = Self.dateWithValues(1970, 1, 1, 0, 0, 0)
		XCTAssertEqual(epoch.timeIntervalSince1970, 0)
		assertParsedDate("1970-01-01T00:00:00Z", epoch)
	}

	func testFarFutureYear() {
		assertParsedDate("2099-12-31T23:59:59Z",
		                 Self.dateWithValues(2099, 12, 31, 23, 59, 59))
	}

	// MARK: - Date math

	func testLeapYearFeb29() {
		// 2020 was a leap year.
		assertParsedDate("2020-02-29T12:00:00Z",
		                 Self.dateWithValues(2020, 2, 29, 12, 0, 0))
	}

	func testNonLeapYearFebMarchBoundary() {
		// 2021 is not a leap year; Feb 28 → Mar 1 crossing.
		assertParsedDate("2021-02-28T23:59:59Z",
		                 Self.dateWithValues(2021, 2, 28, 23, 59, 59))
		assertParsedDate("2021-03-01T00:00:00Z",
		                 Self.dateWithValues(2021, 3, 1, 0, 0, 0))
	}

	// MARK: - Milliseconds

	func testMillisecondsStandard() {
		// Feedbin-style: trailing zeros, treated as ms.
		assertParsedDate("2019-09-27T21:01:48.000000Z",
		                 Self.dateWithValues(2019, 9, 27, 21, 1, 48),
		                 accuracy: 0.000001)
	}

	func testMillisecondsTruncatedBeyondThreeDigits() {
		// Only first 3 digits of the fractional second are kept; extras are skipped.
		assertParsedDate("2021-03-29T10:46:56.516941+00:00",
		                 Self.dateWithValues(2021, 3, 29, 10, 46, 56, 516),
		                 accuracy: 0.000001)
	}

	// MARK: - Boundaries

	func testEmptyInputReturnsNil() {
		assertNilResult("")
	}

	func testTooShortInputReturnsNil() {
		// count < 6 is rejected up front.
		assertNilResult("abc")
		assertNilResult("2010-")
	}

	func testTooLongInputReturnsNil() {
		// count > 150 is rejected.
		let tooLong = String(repeating: "x", count: 200)
		assertNilResult(tooLong)
	}

	// MARK: - Performance

	/// Byte-slice hot path with a mix of pubDate and W3C formats, including one
	/// that hits the timezone-abbreviation dictionary.
	func testHotPathPerformance() {
		let inputs = [
			"Fri, 28 May 2010 21:03:38 GMT",
			"2010-05-28T21:03:38+00:00",
			"Sun, 12 Apr 2026 17:24:19 +0000",
			"2021-03-29T10:46:56.516941+00:00",
			"Wed, 09 Jun 2010 00:00 EST",
			"2010-11-17T08:40:07-05:00"
		].map { ArraySlice(Array($0.utf8)) }

		self.measure {
			for _ in 0..<5000 {
				for bytes in inputs {
					_ = DateParser.date(bytes: bytes)
				}
			}
		}
	}
}
