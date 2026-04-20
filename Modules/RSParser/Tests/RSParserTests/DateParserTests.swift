//
//  DateParserTests.swift
//  RSParserTests
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation
import Testing
@testable import RSParser

// Every correctness test goes through `assertParsedDate` which exercises both
// public entry points — `date(from:)` and `date(bytes:)` — and verifies they
// produce identical results.

@Suite struct DateParserTests {

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
	                              sourceLocation: SourceLocation = #_sourceLocation) {
		let fromString = DateParser.date(from: input)
		let fromBytes = DateParser.date(bytes: ArraySlice(Array(input.utf8)))

		#expect(fromString != nil, "date(from:) returned nil for \(input)", sourceLocation: sourceLocation)
		#expect(fromBytes != nil, "date(bytes:) returned nil for \(input)", sourceLocation: sourceLocation)
		guard let fromString, let fromBytes else {
			return
		}

		if accuracy > 0 {
			#expect(abs(fromString.timeIntervalSince1970 - expected.timeIntervalSince1970) < accuracy, "date(from:) mismatch for \(input)", sourceLocation: sourceLocation)
			#expect(abs(fromBytes.timeIntervalSince1970 - expected.timeIntervalSince1970) < accuracy, "date(bytes:) mismatch for \(input)", sourceLocation: sourceLocation)
		} else {
			#expect(fromString == expected, "date(from:) mismatch for \(input)", sourceLocation: sourceLocation)
			#expect(fromBytes == expected, "date(bytes:) mismatch for \(input)", sourceLocation: sourceLocation)
		}
		#expect(fromString == fromBytes, "String and bytes paths disagreed for \(input)", sourceLocation: sourceLocation)
	}

	private func assertNilResult(_ input: String,
	                             sourceLocation: SourceLocation = #_sourceLocation) {
		#expect(DateParser.date(from: input) == nil, "expected nil for \(input.debugDescription)", sourceLocation: sourceLocation)
		let bytes = ArraySlice(Array(input.utf8))
		#expect(DateParser.date(bytes: bytes) == nil, "expected nil for bytes of \(input.debugDescription)", sourceLocation: sourceLocation)
	}

	// MARK: - Format: pubDate (RFC 822)

	@Test func pubDateStandardForms() {
		let expected = Self.dateWithValues(2010, 5, 28, 21, 3, 38)
		assertParsedDate("Fri, 28 May 2010 21:03:38 GMT", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 +0000", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 -0000", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 +00:00", expected)
		assertParsedDate("Fri, 28 May 2010 21:03:38 -00:00", expected)
	}

	@Test func pubDateWithoutWeekday() {
		assertParsedDate("21 May 2010 21:22:53 GMT",
		                 Self.dateWithValues(2010, 5, 21, 21, 22, 53))
	}

	@Test func pubDateWithoutSeconds() {
		assertParsedDate("Fri, 28 May 2010 21:03 GMT",
		                 Self.dateWithValues(2010, 5, 28, 21, 3, 0))
		assertParsedDate("30 Apr 2010 5:00 PDT",
		                 Self.dateWithValues(2010, 4, 30, 12, 0, 0))
	}

	// MARK: - Format: W3C / ISO 8601

	@Test func w3cStandardForms() {
		let expected = Self.dateWithValues(2010, 5, 28, 21, 3, 38)
		assertParsedDate("2010-05-28T21:03:38Z", expected)
		assertParsedDate("2010-05-28T21:03:38+00:00", expected)
		assertParsedDate("2010-05-28T21:03:38-00:00", expected)
		assertParsedDate("2010-05-28T21:03:38+0000", expected)
		assertParsedDate("2010-05-28T21:03:38-0000", expected)
	}

	@Test func w3cMissingTSeparator() {
		// Atom feeds in the wild sometimes use a space where the spec wants `T`.
		assertParsedDate("2010-11-17 08:40:07-05:00",
		                 Self.dateWithValues(2010, 11, 17, 13, 40, 7))
	}

	@Test func w3cWithOffset() {
		assertParsedDate("2010-11-17T08:40:07-05:00",
		                 Self.dateWithValues(2010, 11, 17, 13, 40, 7))
		assertParsedDate("2010-07-13T17:06:40+00:00",
		                 Self.dateWithValues(2010, 7, 13, 17, 6, 40))
	}

	// MARK: - Time zones: half-hour / 45-min / extremes

	@Test func halfHourOffsets() {
		assertParsedDate("2010-05-28T21:03:38+05:30",
		                 Self.dateWithValues(2010, 5, 28, 15, 33, 38))
		assertParsedDate("2010-05-28T21:03:38+09:30",
		                 Self.dateWithValues(2010, 5, 28, 11, 33, 38))
		assertParsedDate("2010-05-28T21:03:38-02:30",
		                 Self.dateWithValues(2010, 5, 28, 23, 33, 38))
	}

	@Test func fortyFiveMinuteOffsets() {
		assertParsedDate("2010-05-28T21:03:38+05:45",
		                 Self.dateWithValues(2010, 5, 28, 15, 18, 38))
		assertParsedDate("2010-05-28T21:03:38+12:45",
		                 Self.dateWithValues(2010, 5, 28, 8, 18, 38))
	}

	@Test func extremeNumericOffsets() {
		assertParsedDate("2010-05-28T21:03:38+14:00",
		                 Self.dateWithValues(2010, 5, 28, 7, 3, 38))
		assertParsedDate("2010-05-28T21:03:38-12:00",
		                 Self.dateWithValues(2010, 5, 29, 9, 3, 38))
	}

	// MARK: - Time zones: abbreviations

	@Test func timeZoneAbbreviations() {
		assertParsedDate("Wed, 23 Jun 2010 03:43:50 Z",
		                 Self.dateWithValues(2010, 6, 23, 3, 43, 50))
		assertParsedDate("Wed, 09 Jun 2010 00:00 EST",
		                 Self.dateWithValues(2010, 6, 9, 5, 0, 0))
		assertParsedDate("Wed, 09 Jun 2010 09:00:00 JST",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
		assertParsedDate("Wed, 09 Jun 2010 01:00:00 CET",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
		assertParsedDate("Wed, 09 Jun 2010 02:00:00 IST",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
		assertParsedDate("Wed, 09 Jun 2010 10:00:00 AEST",
		                 Self.dateWithValues(2010, 6, 9, 0, 0, 0))
	}

	@Test func timeZoneLowercaseZ() {
		assertParsedDate("2010-05-28T21:03:38z",
		                 Self.dateWithValues(2010, 5, 28, 21, 3, 38))
	}

	@Test func unknownTimeZoneAbbreviation() {
		assertParsedDate("Fri, 28 May 2010 21:03:38 XYZ",
		                 Self.dateWithValues(2010, 5, 28, 21, 3, 38))
	}

	// MARK: - Months

	@Test("All twelve months resolve to 1–12",
	      arguments: [
	          ("Jan", 1), ("Feb", 2), ("Mar", 3), ("Apr", 4),
	          ("May", 5), ("Jun", 6), ("Jul", 7), ("Aug", 8),
	          ("Sep", 9), ("Oct", 10), ("Nov", 11), ("Dec", 12)
	      ])
	func allTwelveMonths(_ monthName: String, _ month: Int) {
		let input = "15 \(monthName) 2020 12:00:00 GMT"
		assertParsedDate(input, Self.dateWithValues(2020, month, 15, 12, 0, 0))
	}

	@Test("Month names are case-insensitive",
	      arguments: ["Jan", "jan", "JAN", "jAN"])
	func caseInsensitiveMonthName(_ monthName: String) {
		let expected = Self.dateWithValues(2020, 1, 15, 12, 0, 0)
		assertParsedDate("15 \(monthName) 2020 12:00:00 GMT", expected)
	}

	// MARK: - Years

	@Test func twoDigitYear() {
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

	@Test func epochBoundary() {
		let epoch = Self.dateWithValues(1970, 1, 1, 0, 0, 0)
		#expect(epoch.timeIntervalSince1970 == 0)
		assertParsedDate("1970-01-01T00:00:00Z", epoch)
	}

	@Test func farFutureYear() {
		assertParsedDate("2099-12-31T23:59:59Z",
		                 Self.dateWithValues(2099, 12, 31, 23, 59, 59))
	}

	// MARK: - Date math

	@Test func leapYearFeb29() {
		assertParsedDate("2020-02-29T12:00:00Z",
		                 Self.dateWithValues(2020, 2, 29, 12, 0, 0))
	}

	@Test func nonLeapYearFebMarchBoundary() {
		assertParsedDate("2021-02-28T23:59:59Z",
		                 Self.dateWithValues(2021, 2, 28, 23, 59, 59))
		assertParsedDate("2021-03-01T00:00:00Z",
		                 Self.dateWithValues(2021, 3, 1, 0, 0, 0))
	}

	// MARK: - Milliseconds

	@Test func millisecondsStandard() {
		assertParsedDate("2019-09-27T21:01:48.000000Z",
		                 Self.dateWithValues(2019, 9, 27, 21, 1, 48),
		                 accuracy: 0.000001)
	}

	@Test func millisecondsTruncatedBeyondThreeDigits() {
		assertParsedDate("2021-03-29T10:46:56.516941+00:00",
		                 Self.dateWithValues(2021, 3, 29, 10, 46, 56, 516),
		                 accuracy: 0.000001)
	}

	// MARK: - Boundaries

	@Test func emptyInputReturnsNil() {
		assertNilResult("")
	}

	@Test func tooShortInputReturnsNil() {
		// count < 6 is rejected up front.
		assertNilResult("abc")
		assertNilResult("2010-")
	}

	@Test func tooLongInputReturnsNil() {
		// count > 150 is rejected.
		let tooLong = String(repeating: "x", count: 200)
		assertNilResult(tooLong)
	}
}
