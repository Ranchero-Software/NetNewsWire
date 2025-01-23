//
//  DateParser.swift
//
//
//  Created by Brent Simmons on 8/28/24.
//

import Foundation

public final class DateParser {

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
			} else if dateIsPubDate(buffer, numberOfBytes) {
				return parsePubDate(buffer, numberOfBytes)
			}

			// Fallback, in case our detection fails.
			return parseW3CDate(buffer, numberOfBytes)
		}
	}

	public static func date(string: String) -> Date? {

		guard let data = string.data(using: .utf8) else {
			return nil
		}
		return date(data: data)
	}

	private typealias DateBuffer = UnsafeBufferPointer<UInt8>

	// See http://en.wikipedia.org/wiki/List_of_time_zone_abbreviations for list
	private static let timeZoneTable: [String: Int] = [

		"GMT": timeZoneOffset(0, 0),
		"UTC": timeZoneOffset(0, 0),
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
}

// MARK: - Private

private extension DateParser {

	struct DateCharacter {

		static let space = Character(" ").asciiValue!
		static let `return` = Character("\r").asciiValue!
		static let newline = Character("\n").asciiValue!
		static let tab = Character("\t").asciiValue!
		static let hyphen = Character("-").asciiValue!
		static let comma = Character(",").asciiValue!
		static let dot = Character(".").asciiValue!
		static let colon = Character(":").asciiValue!
		static let plus = Character("+").asciiValue!
		static let minus = Character("-").asciiValue!
		static let A = Character("A").asciiValue!
		static let a = Character("a").asciiValue!
		static let D = Character("D").asciiValue!
		static let d = Character("d").asciiValue!
		static let F = Character("F").asciiValue!
		static let f = Character("f").asciiValue!
		static let J = Character("J").asciiValue!
		static let j = Character("j").asciiValue!
		static let M = Character("M").asciiValue!
		static let m = Character("m").asciiValue!
		static let N = Character("N").asciiValue!
		static let n = Character("n").asciiValue!
		static let O = Character("O").asciiValue!
		static let o = Character("o").asciiValue!
		static let S = Character("S").asciiValue!
		static let s = Character("s").asciiValue!
		static let U = Character("U").asciiValue!
		static let u = Character("u").asciiValue!
		static let Y = Character("Y").asciiValue!
		static let y = Character("y").asciiValue!
		static let Z = Character("Z").asciiValue!
		static let z = Character("z").asciiValue!
	}

	enum Month: Int {

		case January = 1,
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

	private static func dateIsW3CDate(_ bytes: DateBuffer, _ numberOfBytes: Int) -> Bool {

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
			return Bool(isDigit(ch)) && isDigit(bytes[i + 1]) && isDigit(bytes[i + 2]) && isDigit(bytes[i + 3]) && bytes[i + 4] == DateCharacter.hyphen
		}

		return false
	}

	private static func dateIsPubDate(_ bytes: DateBuffer, _ numberOfBytes: Int) -> Bool {

		for ch in bytes {
			if ch == DateCharacter.space || ch == DateCharacter.comma {
				return true
			}
		}

		return false
	}

	private static func parseW3CDate(_ bytes: DateBuffer, _ numberOfBytes: Int) -> Date? {

		/*@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"
		 @"yyyy-MM-dd'T'HH:mm:sszzz"
		 @"yyyy-MM-dd'T'HH:mm:ss'.'SSSzzz"
		 etc.*/

		var finalIndex = 0

		guard let year = nextNumericValue(bytes, numberOfBytes, 0, 4, &finalIndex) else {
			return nil
		}
		guard let month = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) else {
			return nil
		}
		guard let day = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) else {
			return nil
		}
		let hour = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) ?? 0
		let minute = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) ?? 0
		let second = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) ?? 0

		var currentIndex = finalIndex + 1

		let milliseconds = {
			var ms = 0
			let hasMilliseconds = (currentIndex < numberOfBytes) && (bytes[currentIndex] == DateCharacter.dot)
			if hasMilliseconds {
				ms = nextNumericValue(bytes, numberOfBytes, currentIndex, 3, &finalIndex) ?? 00
				currentIndex = finalIndex + 1
			}

			// Ignore more than 3 digits of precision
			while currentIndex < numberOfBytes && isDigit(bytes[currentIndex]) {
				currentIndex += 1
			}

			return ms
		}()

		let timeZoneOffset = parsedTimeZoneOffset(bytes, numberOfBytes, currentIndex)

		return dateWithYearMonthDayHourMinuteSecondAndtimeZoneOffset(year, month, day, hour, minute, second, milliseconds, timeZoneOffset)
	}

	private static func parsePubDate(_ bytes: DateBuffer, _ numberOfBytes: Int) -> Date? {

		var finalIndex = 0

		let day = nextNumericValue(bytes, numberOfBytes, 0, 2, &finalIndex) ?? 1
		let month = nextMonthValue(bytes, numberOfBytes, finalIndex + 1, &finalIndex) ?? .January

		guard let year = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 4, &finalIndex) else {
			return nil
		}

		let hour = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) ?? 0
		let minute = nextNumericValue(bytes, numberOfBytes, finalIndex + 1, 2, &finalIndex) ?? 0

		var currentIndex = finalIndex + 1

		let second = {
			var s = 0
			let hasSeconds = (currentIndex < numberOfBytes) && (bytes[currentIndex] == DateCharacter.colon)
			if hasSeconds {
				s = nextNumericValue(bytes, numberOfBytes, currentIndex, 2, &finalIndex) ?? 0
			}
			return s
		}()

		currentIndex = finalIndex + 1

		let timeZoneOffset = {
			var offset = 0
			let hasTimeZone = (currentIndex < numberOfBytes) && (bytes[currentIndex] == DateCharacter.space)
			if hasTimeZone {
				offset = parsedTimeZoneOffset(bytes, numberOfBytes, currentIndex)
			}
			return offset
		}()

		return dateWithYearMonthDayHourMinuteSecondAndtimeZoneOffset(year, month.rawValue, day, hour, minute, second, 0, timeZoneOffset)
	}

	// MARK: - Date Creation

	static func dateWithYearMonthDayHourMinuteSecondAndtimeZoneOffset(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int, _ milliseconds: Int, _ timeZoneOffset: Int) -> Date? {

		var timeInfo = tm()
		timeInfo.tm_sec = CInt(second)
		timeInfo.tm_min = CInt(minute)
		timeInfo.tm_hour = CInt(hour)
		timeInfo.tm_mday = CInt(day)
		timeInfo.tm_mon = CInt(month - 1) // It's 1-based coming in
		timeInfo.tm_year = CInt(year - 1900) // see time.h -- it's years since 1900
		timeInfo.tm_wday = -1
		timeInfo.tm_yday = -1
		timeInfo.tm_isdst = -1
		timeInfo.tm_gmtoff = 0
		timeInfo.tm_zone = nil

		let rawTime = timegm(&timeInfo) - timeZoneOffset
		if rawTime == time_t(UInt32.max) {

			// NSCalendar is super-amazingly slow (which is partly why this parser exists),
			// so this is used only when the date is far enough in the future
			// (19 January 2038 03:14:08Z on 32-bit systems) that timegm fails.
			// Hopefully by the time we consistently need dates that far in the future
			// the performance of NSCalendar won’t be an issue.

			var dateComponents = DateComponents()

			dateComponents.timeZone = TimeZone(secondsFromGMT: timeZoneOffset)
			dateComponents.year = year
			dateComponents.month = month
			dateComponents.day = day
			dateComponents.hour = hour
			dateComponents.minute = minute
			dateComponents.second = second
			dateComponents.nanosecond = milliseconds * 1000000

			return Calendar.autoupdatingCurrent.date(from: dateComponents)
		}

		var timeInterval = TimeInterval(rawTime)
		if milliseconds > 0 {
			timeInterval += TimeInterval(TimeInterval(milliseconds) / 1000.0)
		}

		return Date(timeIntervalSince1970: timeInterval)
	}

	// MARK: - Time Zones and Offsets

	private static func parsedTimeZoneOffset(_ bytes: DateBuffer, _ numberOfBytes: Int, _ startingIndex: Int) -> Int {

		var timeZoneCharacters: [UInt8] = [0, 0, 0, 0, 0, 0] // nil-terminated last character
		var numberOfCharactersFound = 0
		var hasAtLeastOneAlphaCharacter = false

		for i in startingIndex..<numberOfBytes {
			let ch = bytes[i]
			if ch == DateCharacter.colon || ch == DateCharacter.space {
				continue
			}
			let isAlphaCharacter = isAlpha(ch)
			if isAlphaCharacter {
				hasAtLeastOneAlphaCharacter = true
			}
			if isAlphaCharacter || isDigit(ch) || ch == DateCharacter.plus || ch == DateCharacter.minus {
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

		if hasAtLeastOneAlphaCharacter {
			return offsetInSecondsForTimeZoneAbbreviation(timeZoneCharacters) ?? 0
		}
		return offsetInSecondsForOffsetCharacters(timeZoneCharacters)
	}

	private static func offsetInSecondsForOffsetCharacters(_ timeZoneCharacters: [UInt8]) -> Int {

		let isPlus = timeZoneCharacters[0] == DateCharacter.plus
		var finalIndex = 0
		let numberOfCharacters = strlen(timeZoneCharacters)

		return timeZoneCharacters.withUnsafeBufferPointer { bytes in
			let hours = nextNumericValue(bytes, numberOfCharacters, 0, 2, &finalIndex) ?? 0
			let minutes = nextNumericValue(bytes, numberOfCharacters, finalIndex + 1, 2, &finalIndex) ?? 0

			if hours == 0 && minutes == 0 {
				return 0
			}

			var seconds = (hours * 60 * 60) + (minutes * 60)
			if !isPlus {
				seconds = 0 - seconds
			}

			return seconds
		}
	}

	/// Returns offset in seconds.
	static func timeZoneOffset(_ hours: Int, _ minutes: Int) -> Int {

		if hours < 0 {
			return (hours * 60 * 60) - (minutes * 60)
		}
		return (hours * 60 * 60) + (minutes * 60)
	}

	private static func offsetInSecondsForTimeZoneAbbreviation(_ abbreviation: [UInt8]) -> Int? {

		var characters = [UInt8]()
		for character in abbreviation {
			if character == 0 {
				break
			}
			characters.append(character)
		}

		let name = String(decoding: characters, as: UTF8.self)
		return timeZoneTable[name]
	}

	// MARK: - Parser

	private static func nextMonthValue(_ bytes: DateBuffer, _ numberOfBytes: Int, _ startingIndex: Int, _ finalIndex: inout Int) -> DateParser.Month? {

		// Lots of short-circuits here. Not strict.

		var numberOfAlphaCharactersFound = 0
		var monthCharacters: [CChar] = [0, 0, 0]

		for i in startingIndex..<numberOfBytes {

			finalIndex = i
			let ch = bytes[i]

			let isAlphaCharacter = isAlpha(ch)
			if !isAlphaCharacter {
				if numberOfAlphaCharactersFound < 1 {
					continue
				}
				if numberOfAlphaCharactersFound > 0 {
					break
				}
			}

			numberOfAlphaCharactersFound+=1
			if numberOfAlphaCharactersFound == 1 {
				if ch == DateCharacter.F || ch == DateCharacter.f {
					return .February
				}
				if ch == DateCharacter.S || ch == DateCharacter.s {
					return .September
				}
				if ch == DateCharacter.O || ch == DateCharacter.o {
					return .October
				}
				if ch == DateCharacter.N || ch == DateCharacter.n {
					return .November
				}
				if ch == DateCharacter.D || ch == DateCharacter.d {
					return .December
				}
			}

			monthCharacters[numberOfAlphaCharactersFound - 1] = CChar(ch)
			if numberOfAlphaCharactersFound >= 3 {
				break
			}
		}

		if numberOfAlphaCharactersFound < 2 {
			return nil
		}

		if monthCharacters[0] == DateCharacter.J || monthCharacters[0] == DateCharacter.j { // Jan, Jun, Jul
			if monthCharacters[1] == DateCharacter.A || monthCharacters[1] == DateCharacter.a {
				return .January
			}
			if monthCharacters[1] == DateCharacter.U || monthCharacters[1] == DateCharacter.u {
				if monthCharacters[2] == DateCharacter.N || monthCharacters[2] == DateCharacter.n {
					return .June
				}
				return .July
			}
			return .January
		}

		if monthCharacters[0] == DateCharacter.M || monthCharacters[0] == DateCharacter.m { // March, May
			if monthCharacters[2] == DateCharacter.Y || monthCharacters[2] == DateCharacter.y {
				return .May
			}
			return .March
		}

		if monthCharacters[0] == DateCharacter.A || monthCharacters[0] == DateCharacter.a { // April, August
			if monthCharacters[1] == DateCharacter.U || monthCharacters[1] == DateCharacter.u {
				return .August
			}
			return .April
		}

		return .January // Should never get here (but possibly do)
	}

	private static func nextNumericValue(_ bytes: DateBuffer, _ numberOfBytes: Int, _ startingIndex: Int, _ maximumNumberOfDigits: Int, _ finalIndex: inout Int) -> Int? {

		// Maximum for the maximum is 4 (for time zone offsets and years)
		assert(maximumNumberOfDigits > 0 && maximumNumberOfDigits <= 4)

		var numberOfDigitsFound = 0
		var digits = [0, 0, 0, 0]

		for i in startingIndex..<numberOfBytes {

			finalIndex = i
			let ch = Int(bytes[i])

			let isDigit = isDigit(ch)
			if !isDigit && numberOfDigitsFound < 1 {
				continue
			}
			if !isDigit && numberOfDigitsFound > 0 {
				break
			}

			digits[numberOfDigitsFound] = ch - 48 // '0' is 48
			numberOfDigitsFound+=1
			if numberOfDigitsFound >= maximumNumberOfDigits {
				break
			}
		}

		if numberOfDigitsFound < 1 {
			return nil
		}

		if numberOfDigitsFound == 1 {
			return digits[0]
		}
		if numberOfDigitsFound == 2 {
			return (digits[0] * 10) + digits[1]
		}
		if numberOfDigitsFound == 3 {
			return (digits[0] * 100) + (digits[1] * 10) + digits[2]
		}
		return (digits[0] * 1000) + (digits[1] * 100) + (digits[2] * 10) + digits[3]
	}

	static func isDigit<T: BinaryInteger>(_ ch: T) -> Bool {

		return isdigit(Int32(ch)) != 0
	}

	static func isAlpha<T: BinaryInteger>(_ ch: T) -> Bool {

		return isalpha(Int32(ch)) != 0
	}
}
