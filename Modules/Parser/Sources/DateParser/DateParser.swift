//
//  DateParser.swift
//
//
//  Created by Brent Simmons on 8/28/24.
//

import Foundation

public final class DateParser {

	typealias DateBuffer = UnsafeBufferPointer<UInt8>

	// MARK: - Public API

	/// Parse W3C and pubDate dates — used for feed parsing.
	/// This is a fast alternative to system APIs
	/// for parsing dates.
	public static func date(data: Data) -> Date? {

		let numberOfBytes = data.count

		// Make sure it’s in reasonable range for a date string.
		if numberOfBytes < 6 || numberOfBytes > 150 {
			return nil
		}

		return data.withUnsafeBytes { bytes in
			let buffer = bytes.bindMemory(to: UInt8.self)

			if dateIsW3CDate(buffer, numberOfBytes) {
				return parseW3CDate(buffer, numberOfBytes)
			}
			else if dateIsPubDate(buffer, numberOfBytes) {
				return parsePubDate(buffer, numberOfBytes)
			}

			// Fallback, in case our detection fails.
			return parseW3CDate(buffer, numberOfBytes)
		}
	}
}

// MARK: - Private

private extension DateParser {

	struct DateCharacter {

		static let space = Character(" ").asciiValue
		static let `return` = Character("\r").asciiValue
		static let newline = Character("\n").asciiValue
		static let tab = Character("\t").asciiValue
		static let hyphen = Character("-").asciiValue
		static let comma = Character(",").asciiValue
		static let dot = Character(".").asciiValue
		static let colon = Character(":").asciiValue
		static let plus = Character("+").asciiValue
		static let minus = Character("-").asciiValue
		static let Z = Character("Z").asciiValue
		static let z = Character("z").asciiValue
		static let F = Character("F").asciiValue
		static let f = Character("f").asciiValue
		static let S = Character("S").asciiValue
		static let s = Character("s").asciiValue
		static let O = Character("O").asciiValue
		static let o = Character("o").asciiValue
		static let N = Character("N").asciiValue
		static let n = Character("n").asciiValue
		static let D = Character("D").asciiValue
		static let d = Character("d").asciiValue
	}

	enum Month: Int {

		January = 1,
		February,
		March,
		April,
		May,
		June,
		July,
		August,
		September,
		October,
		November,
		December
	}

	// MARK: - Standard Formats

	static func dateIsW3CDate(_ bytes: DateBuffer, numberOfBytes: Int) -> Bool {

		// Something like 2010-11-17T08:40:07-05:00
		// But might be missing T character in the middle.
		// Looks for four digits in a row followed by a -.

		for i in 0..<numberOfBytes - 4 {

			let ch = bytes[i]
			// Skip whitespace.
			if ch == DateCharacter.space || ch == DateCharacter.`return` || ch == DateCharacter.newline || ch == DateCharacter.tab {
				continue
			}

			assert(i + 4 < numberOfBytes)
			// First non-whitespace character must be the beginning of the year, as in `2010-`
			return isdigit(ch) && isdigit(bytes[i + 1]) && isdigit(bytes[i + 2]) && isdigit(bytes[i + 3]) && bytes[i + 4] == DateCharacter.hyphen
		}

		return false
	}

	static func dateIsPubDate(_ bytes: DateBuffer, numberOfBytes: Int) -> Bool {

		for ch in bytes {
			if ch == DateCharacter.space || ch == DateCharacter.comma {
				return true
			}
		}

		return false
	}

	static func parseW3CDate(_ bytes: DateBuffer, numberOfBytes: Int) -> Date {

		/*@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"
		 @"yyyy-MM-dd'T'HH:mm:sszzz"
		 @"yyyy-MM-dd'T'HH:mm:ss'.'SSSzzz"
		 etc.*/

		var finalIndex = 0

		let year = nextNumericValue(bytes, numberOfBytes, 0, 4, &finalIndex)
		let month = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex)
		let day = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex)
		let hour = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex)
		let minute = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex)
		let second = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex)

		let currentIndex = finalIndex + 1

		let milliseconds = {
			var ms = 0
			let hasMilliseconds = (currentIndex < numberOfBytes) && (bytes[currentIndex] == DateCharacter.dot)
			if hasMilliseconds {
				ms = nextNumericValue(bytes, numberOfBytes, currentIndex, 3, &finalIndex)
				currentIndex = finalIndex + 1
			}
			return ms
		}()

		let timeZoneOffset = parsedtimeZoneOffset(bytes, numberOfBytes, currentIndex)

		return dateWithYearMonthDayHourMinuteSecondAndtimeZoneOffset(year, month, day, hour, minute, second, milliseconds, timeZoneOffset)
	}

	static func parsePubDate(_ bytes: DateBuffer, numberOfBytes: Int) -> Date {

		var finalIndex = 0

		let day = nextNumericValue(bytes, numberOfBytes, 0, 2, &finalIndex) ?? 1
		let month = nextMonthValue(bytes, numberOfBytes, finalIndex + 1, &finalIndex)
		let year = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 4, &finalIndex)
		let hour = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) ?? 0
		let minute = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) ?? 0

		var currentIndex = finalIndex + 1

		let second = {
			var s = 0
			let hasSeconds = (currentIndex < numberOfBytes) && (bytes[currentIndex] == DateCharacter.colon)
			if hasSeconds {
				s = nextNumericValue(bytes, numberOfBytes, currentIndex, 2, &finalIndex)
			}
			return s
		}()

		currentIndex = finalIndex + 1

		let timeZoneOffset = {
			var offset = 0
			let hasTimeZone = (currentIndex < numberOfBytes) && (bytes[currentIndex] == DateCharacter.space)
			if hasTimeZone {
				offset = parsedtimeZoneOffset(bytes, numberOfBytes, currentIndex)
			}
			return offset
		}()

		return dateWithYearMonthDayHourMinuteSecondAndtimeZoneOffset(year, month, day, hour, minute, second, 0, timeZoneOffset)
	}

	// MARK: - Date Creation

	static func dateWithYearMonthDayHourMinuteSecondAndtimeZoneOffset(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int, _ milliseconds: Int, _ timeZoneOffset: Int) {

		var timeInfo = tm()
		timeInfo.tm_sec = CInt(second)
		timeInfo.tm_min = CInt(minute)
		timeInfo.tm_hour = CInt(hour)
		timeInfo.tm_mday = CInt(day)
		timeInfo.tm_mon = CInt(month - 1) //It's 1-based coming in
		timeInfo.tm_year = CInt(year - 1900) //see time.h -- it's years since 1900
		timeInfo.tm_wday = -1
		timeInfo.tm_yday = -1
		timeInfo.tm_isdst = -1
		timeInfo.tm_gmtoff = timeZoneOffset;
		timeInfo.tm_zone = nil;

		var rawTime = timegm(&timeInfo)
		if rawTime == time_t(UInt.max) {

			// NSCalendar is super-amazingly slow (which is partly why this parser exists),
			// so this is used only when the date is far enough in the future
			// (19 January 2038 03:14:08Z on 32-bit systems) that timegm fails.
			// Hopefully by the time we consistently need dates that far in the future
			// the performance of NSCalendar won’t be an issue.

			var dateComponents = DateComponents()

			dateComponents.timeZone = TimeZone(forSecondsFromGMT: timeZoneOffset)
			dateComponents.year = year
			dateComponents.month = month
			dateComponents.day = day
			dateComponents.hour = hour
			dateComponents.minute = minute
			dateComponents.second = second + (milliseconds / 1000)

			return Calendar.autoupdatingCurrent.date(from: dateComponents)
		}

		if milliseconds > 0 {
			rawTime += Float(milliseconds) / 1000.0
		}

		return Date(timeIntervalSince1970: rawTime)
	}

	// MARK: - Time Zones and Offsets

	static let kGMT = "GMT".utf8CString
	static let kUTC = "UTC".utf8CString

	static func parsedTimeZoneOffset(_ bytes: DateBuffer, _ numberOfBytes: Int, _ startingIndex: Int) -> Int {

		var timeZoneCharacters: [CChar] = [0, 0, 0, 0, 0, 0] // nil-terminated last character
		var numberOfCharactersFound = 0
		var hasAtLeastOneAlphaCharacter = false

		for i in startingIndex..<numberOfBytes {
			let ch = bytes[i]
			if ch == DateCharacter.colon || ch == DateCharacter.space {
				continue
			}
			let isAlphaCharacter = isalpha(ch)
			if isAlphaCharacter {
				hasAtLeastOneAlphaCharacter = true
			}
			if isAlphaCharacter || isdigit(ch) || ch == DateCharacter.plus || ch == DateCharacter.minus {
				numberOfCharactersFound += 1
				timeZoneCharacters[numberOfCharactersFound - 1] = ch
			}
			if numberOfCharactersFound >= 5 {
				break
			}
		}

		if numberOfCharactersFound < 1 || timeZoneCharacters[0] == DateCharacter.Z || timeZoneCharacters[0] == DateCharacter.z {
			return 0
		}
		if strcasestr(timeZoneCharacters, kGMT) != nil || strcasestr(timeZoneCharacters, kUTC) != nil {
			return 0
		}

		if hasAtLeastOneAlphaCharacter {
			return offsetInSecondsForTimeZoneAbbreviation(timeZoneCharacters)
		}
		return offsetInSecondsForOffsetCharacters(timeZoneCharacters)
	}

	static func offsetInSecondsForOffsetCharacters(_ timeZoneCharacters: DateBuffer) {

		let isPlus = timeZoneCharacters[0] == DateCharacter.plus

		var finalIndex = 0
		let numberOfCharacters = strlen(timeZoneCharacters)
		let hours = nextNumericValue(timeZoneCharacters, numberOfCharacters, 0, 2, &finalIndex) ?? 0
		let minutes = nextNumericValue(timeZoneCharacters, numberOfCharacters, finalIndex + 1, 2, &finalIndex) ?? 0
		
		if hours == 0 && minutes == 0 {
			return 0
		}

		var seconds = (hours * 60 * 60) + (minutes * 60)
		if !isPlus {
			seconds = 0 - seconds
		}

		return seconds
	}

	/// Returns offset in seconds.
	static func timeZoneOffset(_ hours: Int, _ minutes: Int) -> Int {

		if hours < 0 {
			return (hours * 60 * 60) - (minutes * 60)
		}
		return (hours * 60 * 60) + (minutes * 60)
		}

	// See http://en.wikipedia.org/wiki/List_of_time_zone_abbreviations for list
	private let timeZoneTable: [String: Int] = [

		"GMT": timeZoneOffset(0, 0),
		"PDT": timeZoneOffset(-7, 0),
		"PST": timeZoneOffset(-8, 0),
		"EST": timeZoneOffset(-5, 0),
		"EDT": timeZoneOffset(-4, 0),
		"MDT": timeZoneOffset(-6, 0),
		"MST": timeZoneOffset(-7, 0),
		"CST": timeZoneOffset(-6, 0),
		"CDT": timeZoneOffset(-5, 0),
		"ACT": timeZoneOffset(-8, 0),
		"AFT": timeZoneOffset(4, 30),
		"AMT": timeZoneOffset(4, 0),
		"ART": timeZoneOffset(-3, 0),
		"AST": timeZoneOffset(3, 0),
		"AZT": timeZoneOffset(4, 0),
		"BIT": timeZoneOffset(-12, 0),
		"BDT": timeZoneOffset(8, 0),
		"ACST": timeZoneOffset(9, 30),
		"AEST": timeZoneOffset(10, 0),
		"AKST": timeZoneOffset(-9, 0),
		"AMST": timeZoneOffset(5, 0),
		"AWST": timeZoneOffset(8, 0),
		"AZOST": timeZoneOffset(-1, 0),
		"BIOT": timeZoneOffset(6, 0),
		"BRT": timeZoneOffset(-3, 0),
		"BST": timeZoneOffset(6, 0),
		"BTT": timeZoneOffset(6, 0),
		"CAT": timeZoneOffset(2, 0),
		"CCT": timeZoneOffset(6, 30),
		"CET": timeZoneOffset(1, 0),
		"CEST": timeZoneOffset(2, 0),
		"CHAST": timeZoneOffset(12, 45),
		"ChST": timeZoneOffset(10, 0),
		"CIST": timeZoneOffset(-8, 0),
		"CKT": timeZoneOffset(-10, 0),
		"CLT": timeZoneOffset(-4, 0),
		"CLST": timeZoneOffset(-3, 0),
		"COT": timeZoneOffset(-5, 0),
		"COST": timeZoneOffset(-4, 0),
		"CVT": timeZoneOffset(-1, 0),
		"CXT": timeZoneOffset(7, 0),
		"EAST": timeZoneOffset(-6, 0),
		"EAT": timeZoneOffset(3, 0),
		"ECT": timeZoneOffset(-4, 0),
		"EEST": timeZoneOffset(3, 0),
		"EET": timeZoneOffset(2, 0),
		"FJT": timeZoneOffset(12, 0),
		"FKST": timeZoneOffset(-4, 0),
		"GALT": timeZoneOffset(-6, 0),
		"GET": timeZoneOffset(4, 0),
		"GFT": timeZoneOffset(-3, 0),
		"GILT": timeZoneOffset(7, 0),
		"GIT": timeZoneOffset(-9, 0),
		"GST": timeZoneOffset(-2, 0),
		"GYT": timeZoneOffset(-4, 0),
		"HAST": timeZoneOffset(-10, 0),
		"HKT": timeZoneOffset(8, 0),
		"HMT": timeZoneOffset(5, 0),
		"IRKT": timeZoneOffset(8, 0),
		"IRST": timeZoneOffset(3, 30),
		"IST": timeZoneOffset(2, 0),
		"JST": timeZoneOffset(9, 0),
		"KRAT": timeZoneOffset(7, 0),
		"KST": timeZoneOffset(9, 0),
		"LHST": timeZoneOffset(10, 30),
		"LINT": timeZoneOffset(14, 0),
		"MAGT": timeZoneOffset(11, 0),
		"MIT": timeZoneOffset(-9, 30),
		"MSK": timeZoneOffset(3, 0),
		"MUT": timeZoneOffset(4, 0),
		"NDT": timeZoneOffset(-2, 30),
		"NFT": timeZoneOffset(11, 30),
		"NPT": timeZoneOffset(5, 45),
		"NT": timeZoneOffset(-3, 30),
		"OMST": timeZoneOffset(6, 0),
		"PETT": timeZoneOffset(12, 0),
		"PHOT": timeZoneOffset(13, 0),
		"PKT": timeZoneOffset(5, 0),
		"RET": timeZoneOffset(4, 0),
		"SAMT": timeZoneOffset(4, 0),
		"SAST": timeZoneOffset(2, 0),
		"SBT": timeZoneOffset(11, 0),
		"SCT": timeZoneOffset(4, 0),
		"SLT": timeZoneOffset(5, 30),
		"SST": timeZoneOffset(8, 0),
		"TAHT": timeZoneOffset(-10, 0),
		"THA": timeZoneOffset(7, 0),
		"UYT": timeZoneOffset(-3, 0),
		"UYST": timeZoneOffset(-2, 0),
		"VET": timeZoneOffset(-4, 30),
		"VLAT": timeZoneOffset(10, 0),
		"WAT": timeZoneOffset(1, 0),
		"WET": timeZoneOffset(0, 0),
		"WEST": timeZoneOffset(1, 0),
		"YAKT": timeZoneOffset(9, 0),
		"YEKT": timeZoneOffset(5, 0)
	]

	static func offsetInSecondsForTimeZoneAbbreviation(_ abbreviation: DateBuffer) -> Int? {

		let name = String(cString: abbreviation)
		return timeZoneTable[name]
	}

	// MARK: - Parser

	static func nextMonthValue(_ buffer: DateBuffer, _ numberOfBytes: Int, _ startingIndex: Int, _ finalIndex: inout Int) -> DateParser.Month? {

		// Lots of short-circuits here. Not strict.

		var numberOfAlphaCharactersFound = 0
		var monthCharacters: [CChar] = [0, 0, 0]

		for i in startingIndex..<numberOfBytes {

			finalIndex = i
			let ch = bytes[i]
			
			let isAlphaCharacter = isalpha(ch)
			if !isAlphaCharacter {
				if numberOfAlphaCharactersFound < 1 {
					continue
				}
				if numberOfAlphaCharactersFound > 0 {
					break
				}
			}

			numberOfAlphaCharactersFound +=1
			if numberOfAlphaCharactersFound == 1 {
				if ch == DateCharacter.F || ch == DateCharacter.f {
					return February
				}
				if ch == DateCharacter.S || ch == DateCharacter.s {
					return September
				}
				if ch == DateCharacter.O || ch == DateCharacter.o {
					return October
				}
				if ch == DateCharacter.N || ch == DateCharacter.n {
					return November
				}
				if ch == DateCharacter.D || ch == DateCharacter.d {
					return December
				}
			}

			monthCharacters[numberOfAlphaCharactersFound - 1] = character
			if numberOfAlphaCharactersFound >=3
				break
		}

		if numberOfAlphaCharactersFound < 2 {
			return nil
		}

		if monthCharacters[0] == DateCharater.J || monthCharacters[0] == DateCharacter.j { // Jan, Jun, Jul
			if monthCharacters[1] == DateCharacter.A || monthCharacters[1] == DateCharacter.a {
				return Month.January
			}
			if monthCharacters[1] = DateCharacter.U || monthCharacters[1] == DateCharacter.u {
				if monthCharacters[2] == DateCharacter.N || monthCharacters[2] == DateCharacter.n {
					return June
				}
				return July
			}
			return January
		}

		if monthCharacters[0] == DateCharacter.M || monthCharacters[0] == DateCharacter.m { // March, May
			if monthCharacters[2] == DateCharacter.Y || monthCharacters[2] == DateCharacter.y {
				return May
			}
			return March
		}

		if monthCharacters[0] == DateCharacter.A || monthCharacters[0] == DateCharacter.a { // April, August
			if monthCharacters[1] == DateCharacter.U || monthCharacters[1] == DateCharacter.u {
				return August
			}
			return April
		}

		return January // Should never get here (but possibly do)
	}

	static func nextNumericValue(_ bytes: DateBuffer, numberOfBytes: Int, startingIndex: Int, maximumNumberOfDigits: Int, finalIndex: inout Int) -> Int? {

		// Maximum for the maximum is 4 (for time zone offsets and years)
		assert(maximumNumberOfDigits > 0 && maximumNumberOfDigits <= 4)
		
		var numberOfDigitsFound = 0
		var digits = [0, 0, 0, 0]

		for i in startingIndex..<numberOfBytes {

			finalIndex = i

			let isDigit = isDigit(
		}

	}
}
