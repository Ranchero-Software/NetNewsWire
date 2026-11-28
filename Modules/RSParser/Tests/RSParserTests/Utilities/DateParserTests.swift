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

	// https://github.com/Ranchero-Software/NetNewsWire/issues/5469
	@Test func pubDateMonthBeforeDay() {
		// CrowdStrike Blog: month first, offset attached to the time.
		assertParsedDate("Nov 25, 2026 00:00:00-0800",
		                 Self.dateWithValues(2026, 11, 25, 8, 0, 0))
		// NBC New York: weekday, month first, 12-hour time, no time zone.
		assertParsedDate("Fri, Nov 27 2026 02:07:36 PM",
		                 Self.dateWithValues(2026, 11, 27, 14, 7, 36))
		// Aero-News Network: comma attached to the year, AM/PM attached to the time.
		assertParsedDate("Wed, Oct 07,2026 08:06:32PM",
		                 Self.dateWithValues(2026, 10, 7, 20, 6, 32))
		assertParsedDate("Nov 25, 2026",
		                 Self.dateWithValues(2026, 11, 25, 0, 0, 0))
		assertParsedDate("November 25, 2026 10:30 AM EST",
		                 Self.dateWithValues(2026, 11, 25, 15, 30, 0))
		assertParsedDate("Nov 25th, 2026", Self.dateWithValues(2026, 11, 25, 0, 0, 0))
		assertParsedDate("Friday, November 27, 2026 2:07 PM", Self.dateWithValues(2026, 11, 27, 14, 7, 0))
		assertParsedDate("\n  Fri, Nov 27 2026 02:07:36 PM\n", Self.dateWithValues(2026, 11, 27, 14, 7, 36))
	}

	@Test func pubDateAttachedOffset() {
		let expected = Self.dateWithValues(2026, 11, 25, 8, 0, 0)
		assertParsedDate("Nov 25, 2026 00:00:00-0800", expected)
		assertParsedDate("Nov 25, 2026 00:00:00-08:00", expected)
		assertParsedDate("Nov 25, 2026 00:00-0800", expected)
		assertParsedDate("Nov 25, 2026 12:00:00 AM-0800", expected)
		assertParsedDate("25 Nov 2026 10:00:00+0200", expected)
	}

	@Test func weekdayThatLooksLikeMonthStaysDayFirst() {
		// "mar" is Tuesday in French, Spanish and Italian, not March.
		assertParsedDate("mar, 24 nov 2026 10:00:00 +0100", Self.dateWithValues(2026, 11, 24, 9, 0, 0))
		assertParsedDate("Mar, 13 Jan 2026 10:00:00 GMT", Self.dateWithValues(2026, 1, 13, 10, 0, 0))
		assertParsedDate("mardi 24 novembre 2026", Self.dateWithValues(2026, 11, 24, 0, 0, 0))
		assertParsedDate("mar, 01 dic 2026 10:00:00 GMT", Self.dateWithValues(2026, 12, 1, 10, 0, 0))
		assertParsedDate("mar, 03 févr. 2026 10:00:00 GMT", Self.dateWithValues(2026, 2, 3, 10, 0, 0))
		// A month name in an RFC 822 comment doesn't override the real month.
		assertParsedDate("Fri, (March) 27 Nov 2026 10:00:00 GMT", Self.dateWithValues(2026, 11, 27, 10, 0, 0))
	}

	@Test func pubDateTwelveHourClock() {
		assertParsedDate("27 Nov 2026 12:00:00 AM GMT", Self.dateWithValues(2026, 11, 27, 0, 0, 0))
		assertParsedDate("27 Nov 2026 12:00:00 PM GMT", Self.dateWithValues(2026, 11, 27, 12, 0, 0))
		assertParsedDate("27 Nov 2026 12:30 am", Self.dateWithValues(2026, 11, 27, 0, 30, 0))
		assertParsedDate("27 Nov 2026 11:59:59 PM", Self.dateWithValues(2026, 11, 27, 23, 59, 59))
		assertParsedDate("27 Nov 2026 01:15:00 pm +0100", Self.dateWithValues(2026, 11, 27, 12, 15, 0))
		// Already a 24-hour time: PM doesn't add another 12 hours.
		assertParsedDate("27 Nov 2026 14:07:36 PM", Self.dateWithValues(2026, 11, 27, 14, 7, 36))
	}

	@Test func timeZoneStartingWithAMIsNotMeridiem() {
		// AMT (UTC+4) and AMST (UTC+5) must not be read as "AM".
		assertParsedDate("27 Nov 2026 10:00:00 AMT", Self.dateWithValues(2026, 11, 27, 6, 0, 0))
		assertParsedDate("27 Nov 2026 10:00:00 AMST", Self.dateWithValues(2026, 11, 27, 5, 0, 0))
	}

	@Test func pubDateWithoutYearReturnsNil() {
		assertNilResult("27 Nov")
		assertNilResult("Nov 25")
		assertNilResult("Fri, Nov 27")
		// The hour isn't taken as a two-digit year.
		assertNilResult("Nov 27 12:00:00 GMT")
		assertNilResult("Nov 25 10:00 AM")
		assertNilResult("25 Nov 10:00")
		assertNilResult("Fri Nov 27 14:07:36 PST 2026")
		assertNilResult("Fri, Nov 2026")
	}

	@Test func fourDigitYearFollowedByColon() {
		// Only a one- or two-digit number before `:` is taken as the hour.
		assertParsedDate("28 May 2010:21:03:38 GMT", Self.dateWithValues(2010, 5, 28, 21, 3, 38))
	}

	@Test func dateFromSubSliceWithNonZeroStartIndex() {
		let bytes = Array("xxFri, Nov 27 2026 02:07:36 PMyy".utf8)
		let date = DateParser.date(bytes: bytes[2..<(bytes.count - 2)])
		#expect(date == Self.dateWithValues(2026, 11, 27, 14, 7, 36))
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

	@Test func slashDateFormat() {
		// Dvbbs.Net and some CMS feeds emit `YYYY/M/D HH:MM:SS` (not in any spec, but common).
		assertParsedDate("2020/1/10 14:33:00",
		                 Self.dateWithValues(2020, 1, 10, 14, 33, 0))
		assertParsedDate("2020/12/31 23:59:59",
		                 Self.dateWithValues(2020, 12, 31, 23, 59, 59))
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

	// MARK: - Liberal-parse behavior (malformed but plausible-looking input)

	// The parser is intentionally permissive: real-world feed pubDates are a mess,
	// so it accepts more than the specs allow. These tests document current behavior
	// (which is the contract the rest of the app depends on) so a future "tighten
	// it up" change doesn't silently turn these cases into nil. Only a pubDate with
	// no month or year at all returns nil (#5469).

	@Test func unknownMonthNameFallsBackToJanuary() {
		// Unrecognized month string falls back to month=1, day-of-month preserved.
		// Not a guarantee we'd re-derive from scratch today, but it's what real
		// feed content has been parsed against for years.
		let expected = Self.dateWithValues(2010, 1, 28, 21, 3, 38)
		assertParsedDate("Fri, 28 Xyz 2010 21:03:38 GMT", expected)
		assertParsedDate("28 Xyz 2010 21:03:38 GMT", expected)
	}

	@Test func monthPrefixMatchAccepted() {
		// Four-letter "Februar" matches "Feb" by prefix. This was an accidental
		// property of the prefix-match, not a designed feature — documented here
		// so a tightening change flags explicitly.
		assertParsedDate("28 Februar 2010 21:03:38 GMT",
		                 Self.dateWithValues(2010, 2, 28, 21, 3, 38))
	}

	@Test func garbageInputReturnsNil() {
		// No month or year: nil rather than a made-up January 1970 date, so the app
		// falls back to the article's modified or arrival date.
		// https://github.com/Ranchero-Software/NetNewsWire/issues/5469
		assertNilResult("the quick brown fox jumped over")
	}

	@Test func partialISODateAcceptedWithMissingFieldsZeroed() {
		// `YYYY-MM` → first of month, midnight UTC. `YYYY-MM-DD` → midnight UTC.
		// Not strictly W3C but accepted in the wild.
		assertParsedDate("2020-02", Self.dateWithValues(2020, 2, 1, 0, 0, 0))
		assertParsedDate("2020-02-15", Self.dateWithValues(2020, 2, 15, 0, 0, 0))
	}

	@Test func mixedSeparatorsTolerated() {
		// The parser reads numeric fields regardless of whether `-`, `/`, or a
		// mix sits between them. No known real-world feed produces mixed, but
		// a feed that did would not silently drop its date.
		let expected = Self.dateWithValues(2020, 1, 10, 14, 33, 0)
		assertParsedDate("2020-01/10 14:33:00", expected)
		assertParsedDate("2020/01-10 14:33:00", expected)
	}
}
