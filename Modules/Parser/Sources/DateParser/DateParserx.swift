////
////  DateParser.swift
////
////
////  Created by Brent Simmons on 8/28/24.
////
//
//import Foundation
//
//private struct TimeZoneSpecifier {
//	let abbreviation: String
//	let offsetHours: Int
//	let offsetMinutes: Int
//
//	init(_ abbreviation: String, _ offsetHours: Int, _ offsetMinutes: Int) {
//		self.abbreviation = abbreviation
//		self.offsetHours = offsetHours
//		self.offsetMinutes = offsetMinutes
//	}
//}
//
//// See http://en.wikipedia.org/wiki/List_of_time_zone_abbreviations for list
//private let timeZoneTable: [TimeZoneAbbreviationAndOffset] = [
//	// Most common at top for performance
//	TimeZoneSpecifier("GMT", 0, 0),
//	TimeZoneSpecifier("PDT", -7, 0),
//	TimeZoneSpecifier("PST", -8, 0),
//	TimeZoneSpecifier("EST", -5, 0),
//	TimeZoneSpecifier("EDT", -4, 0),
//	TimeZoneSpecifier("MDT", -6, 0),
//	TimeZoneSpecifier("MST", -7, 0),
//	TimeZoneSpecifier("CST", -6, 0),
//	TimeZoneSpecifier("CDT", -5, 0),
//	TimeZoneSpecifier("ACT", -8, 0),
//	TimeZoneSpecifier("AFT", 4, 30),
//	TimeZoneSpecifier("AMT", 4, 0),
//	TimeZoneSpecifier("ART", -3, 0),
//	TimeZoneSpecifier("AST", 3, 0),
//	TimeZoneSpecifier("AZT", 4, 0),
//	TimeZoneSpecifier("BIT", -12, 0),
//	TimeZoneSpecifier("BDT", 8, 0),
//	TimeZoneSpecifier("ACST", 9, 30),
//	TimeZoneSpecifier("AEST", 10, 0),
//	TimeZoneSpecifier("AKST", -9, 0),
//	TimeZoneSpecifier("AMST", 5, 0),
//	TimeZoneSpecifier("AWST", 8, 0),
//	TimeZoneSpecifier("AZOST", -1, 0),
//	TimeZoneSpecifier("BIOT", 6, 0),
//	TimeZoneSpecifier("BRT", -3, 0),
//	TimeZoneSpecifier("BST", 6, 0),
//	TimeZoneSpecifier("BTT", 6, 0),
//	TimeZoneSpecifier("CAT", 2, 0),
//	TimeZoneSpecifier("CCT", 6, 30),
//	TimeZoneSpecifier("CET", 1, 0),
//	TimeZoneSpecifier("CEST", 2, 0),
//	TimeZoneSpecifier("CHAST", 12, 45),
//	TimeZoneSpecifier("ChST", 10, 0),
//	TimeZoneSpecifier("CIST", -8, 0),
//	TimeZoneSpecifier("CKT", -10, 0),
//	TimeZoneSpecifier("CLT", -4, 0),
//	TimeZoneSpecifier("CLST", -3, 0),
//	TimeZoneSpecifier("COT", -5, 0),
//	TimeZoneSpecifier("COST", -4, 0),
//	TimeZoneSpecifier("CVT", -1, 0),
//	TimeZoneSpecifier("CXT", 7, 0),
//	TimeZoneSpecifier("EAST", -6, 0),
//	TimeZoneSpecifier("EAT", 3, 0),
//	TimeZoneSpecifier("ECT", -4, 0),
//	TimeZoneSpecifier("EEST", 3, 0),
//	TimeZoneSpecifier("EET", 2, 0),
//	TimeZoneSpecifier("FJT", 12, 0),
//	TimeZoneSpecifier("FKST", -4, 0),
//	TimeZoneSpecifier("GALT", -6, 0),
//	TimeZoneSpecifier("GET", 4, 0),
//	TimeZoneSpecifier("GFT", -3, 0),
//	TimeZoneSpecifier("GILT", 7, 0),
//	TimeZoneSpecifier("GIT", -9, 0),
//	TimeZoneSpecifier("GST", -2, 0),
//	TimeZoneSpecifier("GYT", -4, 0),
//	TimeZoneSpecifier("HAST", -10, 0),
//	TimeZoneSpecifier("HKT", 8, 0),
//	TimeZoneSpecifier("HMT", 5, 0),
//	TimeZoneSpecifier("IRKT", 8, 0),
//	TimeZoneSpecifier("IRST", 3, 30),
//	TimeZoneSpecifier("IST", 2, 0),
//	TimeZoneSpecifier("JST", 9, 0),
//	TimeZoneSpecifier("KRAT", 7, 0),
//	TimeZoneSpecifier("KST", 9, 0),
//	TimeZoneSpecifier("LHST", 10, 30),
//	TimeZoneSpecifier("LINT", 14, 0),
//	TimeZoneSpecifier("MAGT", 11, 0),
//	TimeZoneSpecifier("MIT", -9, 30),
//	TimeZoneSpecifier("MSK", 3, 0),
//	TimeZoneSpecifier("MUT", 4, 0),
//	TimeZoneSpecifier("NDT", -2, 30),
//	TimeZoneSpecifier("NFT", 11, 30),
//	TimeZoneSpecifier("NPT", 5, 45),
//	TimeZoneSpecifier("NT", -3, 30),
//	TimeZoneSpecifier("OMST", 6, 0),
//	TimeZoneSpecifier("PETT", 12, 0),
//	TimeZoneSpecifier("PHOT", 13, 0),
//	TimeZoneSpecifier("PKT", 5, 0),
//	TimeZoneSpecifier("RET", 4, 0),
//	TimeZoneSpecifier("SAMT", 4, 0),
//	TimeZoneSpecifier("SAST", 2, 0),
//	TimeZoneSpecifier("SBT", 11, 0),
//	TimeZoneSpecifier("SCT", 4, 0),
//	TimeZoneSpecifier("SLT", 5, 30),
//	TimeZoneSpecifier("SST", 8, 0),
//	TimeZoneSpecifier("TAHT", -10, 0),
//	TimeZoneSpecifier("THA", 7, 0),
//	TimeZoneSpecifier("UYT", -3, 0),
//	TimeZoneSpecifier("UYST", -2, 0),
//	TimeZoneSpecifier("VET", -4, 30),
//	TimeZoneSpecifier("VLAT", 10, 0),
//	TimeZoneSpecifier("WAT", 1, 0),
//	TimeZoneSpecifier("WET", 0, 0),
//	TimeZoneSpecifier("WEST", 1, 0),
//	TimeZoneSpecifier("YAKT", 9, 0),
//	TimeZoneSpecifier("YEKT", 5, 0)
//]
//
//private enum Month: Int {
//	case January = 1, February, March, April, May, June, July, August, September, October, November, December
//}
//
//private func nextMonthValue(bytes: String, startingIndex: Int, finalIndex: inout Int) -> Int? {
//
//	// Months are 1-based -- January is 1, Dec is 12.
//	// Lots of short-circuits here. Not strict. GIGO
//
//	var i = startingIndex
//	var numberOfBytes = bytes.count
//	var numberOfAlphaCharactersFound = 0
//	var monthCharacters = [Character]()
//
//	while index < bytes.count {
//
//		
//	}
//
//
//	var index = startingIndex
//	var numberOfAlphaCharactersFound = 0
//	var monthCharacters: [Character] = []
//
//	while index < bytes.count {
//		let character = bytes[bytes.index(bytes.startIndex, offsetBy: index)]
//
//		if !character.isLetter, numberOfAlphaCharactersFound < 1 {
//			index += 1
//			continue
//		}
//		if !character.isLetter, numberOfAlphaCharactersFound > 0 {
//			break
//		}
//
//		numberOfAlphaCharactersFound += 1
//		if numberOfAlphaCharactersFound == 1 {
//			switch character.lowercased() {
//			case "f": return (.February.rawValue, index)
//			case "s": return (.September.rawValue, index)
//			case "o": return (.October.rawValue, index)
//			case "n": return (.November.rawValue, index)
//			case "d": return (.December.rawValue, index)
//			default: break
//			}
//		}
//
//		monthCharacters.append(character)
//		if numberOfAlphaCharactersFound >= 3 {
//			break
//		}
//		index += 1
//	}
//
//	if numberOfAlphaCharactersFound < 2 {
//		return (nil, index)
//	}
//
//	if monthCharacters[0].lowercased() == "j" {
//		if monthCharacters[1].lowercased() == "a" {
//			return (.January.rawValue, index)
//		}
//		if monthCharacters[1].lowercased() == "u" {
//			if monthCharacters.count > 2 && monthCharacters[2].lowercased() == "n" {
//				return (.June.rawValue, index)
//			}
//			return (.July.rawValue, index)
//		}
//		return (.January.rawValue, index)
//	}
//
//	if monthCharacters[0].lowercased() == "m" {
//		if monthCharacters.count > 2 && monthCharacters[2].lowercased() == "y" {
//			return (.May.rawValue, index)
//		}
//		return (.March.rawValue, index)
//	}
//
//	if monthCharacters[0].lowercased() == "a" {
//		if monthCharacters[1].lowercased() == "u" {
//			return (.August.rawValue, index)
//		}
//		return (.April.rawValue, index)
//	}
//
//	return (.January.rawValue, index)
//}
//
//func nextNumericValue(bytes: String, startingIndex: Int, maximumNumberOfDigits: Int) -> (Int?, Int) {
//	let digits = bytes.dropFirst(startingIndex).prefix(maximumNumberOfDigits)
//	guard let value = Int(digits) else {
//		return (nil, startingIndex)
//	}
//	return (value, startingIndex + digits.count)
//}
//
//func hasAtLeastOneAlphaCharacter(_ s: String) -> Bool {
//	return s.contains { $0.isLetter }
//}
//
//func offsetInSeconds(forTimeZoneAbbreviation abbreviation: String) -> Int {
//	for zone in timeZoneTable {
//		if zone.abbreviation.caseInsensitiveCompare(abbreviation) == .orderedSame {
//			if zone.offsetHours < 0 {
//				return (zone.offsetHours * 3600) - (zone.offsetMinutes * 60)
//			}
//			return (zone.offsetHours * 3600) + (zone.offsetMinutes * 60)
//		}
//	}
//	return 0
//}
//
//func offsetInSeconds(forOffsetCharacters timeZoneCharacters: String) -> Int {
//	let isPlus = timeZoneCharacters.hasPrefix("+")
//	let numericValue = timeZoneCharacters.filter { $0.isNumber || $0 == "-" }
//	let (hours, finalIndex) = nextNumericValue(bytes: numericValue, startingIndex: 0, maximumNumberOfDigits: 2)
//	let (minutes, _) = nextNumericValue(bytes: numericValue, startingIndex: finalIndex + 1, maximumNumberOfDigits: 2)
//
//	let seconds = ((hours ?? 0) * 3600) + ((minutes ?? 0) * 60)
//	return isPlus ? seconds : -seconds
//}
//
//func parsedTimeZoneOffset(bytes: String, startingIndex: Int) -> Int {
//	var timeZoneCharacters: String = ""
//	var numberOfCharactersFound = 0
//	var i = startingIndex
//
//	while i < bytes.count, numberOfCharactersFound < 5 {
//		let character = bytes[bytes.index(bytes.startIndex, offsetBy: i)]
//		if character != ":" && character != " " {
//			timeZoneCharacters.append(character)
//			numberOfCharactersFound += 1
//		}
//		i += 1
//	}
//
//	if numberOfCharactersFound < 1 || timeZoneCharacters.lowercased() == "z" {
//		return 0
//	}
//
//	if timeZoneCharacters.range(of: "GMT", options: .caseInsensitive) != nil ||
//		timeZoneCharacters.range(of: "UTC", options: .caseInsensitive) != nil {
//		return 0
//	}
//
//	if hasAtLeastOneAlphaCharacter(timeZoneCharacters) {
//		return offsetInSeconds(forTimeZoneAbbreviation: timeZoneCharacters)
//	}
//	return offsetInSeconds(forOffsetCharacters: timeZoneCharacters)
//}
//
//func dateWithYearMonthDayHourMinuteSecondAndTimeZoneOffset(
//	year: Int, month: Int, day: Int,
//	hour: Int, minute: Int, second: Int,
//	milliseconds: Int, timeZoneOffset: Int) -> Date? {
//
//	var dateComponents = DateComponents()
//	dateComponents.year = year
//	dateComponents.month = month
//	dateComponents.day = day
//	dateComponents.hour = hour
//	dateComponents.minute = minute
//	dateComponents.second = second
//	dateComponents.timeZone = TimeZone(secondsFromGMT: timeZoneOffset)
//
//	let calendar = Calendar.current
//	return calendar.date(from: dateComponents)
//}
//
//func parsePubDate(bytes: String) -> Date? {
//	let (day, finalIndex) = nextNumericValue(bytes: bytes, startingIndex: 0, maximumNumberOfDigits: 2)
//	let (month, finalIndex2) = nextMonthValue(bytes: bytes, startingIndex: finalIndex + 1)
//	let (year, finalIndex3) = nextNumericValue(bytes: bytes, startingIndex: finalIndex2 + 1, maximumNumberOfDigits: 4)
//	let (hour, finalIndex4) = nextNumericValue(bytes: bytes, startingIndex: finalIndex3 + 1, maximumNumberOfDigits: 2)
//	let (minute, finalIndex5) = nextNumericValue(bytes: bytes, startingIndex: finalIndex4 + 1, maximumNumberOfDigits: 2)
//
//	var second = 0
//	let currentIndex = finalIndex5 + 1
//	if currentIndex < bytes.count, bytes[bytes.index(bytes.startIndex, offsetBy: currentIndex)] == ":" {
//		second = nextNumericValue(bytes: bytes, startingIndex: currentIndex, maximumNumberOfDigits: 2).0 ?? 0
//	}
//
//	let timeZoneOffset = parsedTimeZoneOffset(bytes: bytes, startingIndex: currentIndex + 1)
//
//	return dateWithYearMonthDayHourMinuteSecondAndTimeZoneOffset(
//		year: year ?? 1970,
//		month: month ?? RSMonth.January.rawValue,
//		day: day ?? 1,
//		hour: hour ?? 0,
//		minute: minute ?? 0,
//		second: second,
//		milliseconds: 0,
//		timeZoneOffset: timeZoneOffset
//	)
//}
//
//func parseW3C(bytes: String) -> Date? {
//	let (year, finalIndex) = nextNumericValue(bytes: bytes, startingIndex: 0, maximumNumberOfDigits: 4)
//	let (month, finalIndex2) = nextNumericValue(bytes: bytes, startingIndex: finalIndex + 1, maximumNumberOfDigits: 2)
//	let (day, finalIndex3) = nextNumericValue(bytes: bytes, startingIndex: finalIndex2 + 1, maximumNumberOfDigits: 2)
//	let (hour, finalIndex4) = nextNumericValue(bytes: bytes, startingIndex: finalIndex3 + 1, maximumNumberOfDigits: 2)
//	let (minute, finalIndex5) = nextNumericValue(bytes: bytes, startingIndex: finalIndex4 + 1, maximumNumberOfDigits: 2)
//	let (second, finalIndex6) = nextNumericValue(bytes: bytes, startingIndex: finalIndex5 + 1, maximumNumberOfDigits: 2)
//
//	var milliseconds = 0
//	let currentIndex = finalIndex6 + 1
//	if currentIndex < bytes.count, bytes[bytes.index(bytes.startIndex, offsetBy: currentIndex)] == "." {
//		milliseconds = nextNumericValue(bytes: bytes, startingIndex: currentIndex + 1, maximumNumberOfDigits: 3).0 ?? 0
//	}
//
//	let timeZoneOffset = parsedTimeZoneOffset(bytes: bytes, startingIndex: currentIndex + 1)
//
//	return dateWithYearMonthDayHourMinuteSecondAndTimeZoneOffset(
//		year: year ?? 1970,
//		month: month ?? RSMonth.January.rawValue,
//		day: day ?? 1,
//		hour: hour ?? 0,
//		minute: minute ?? 0,
//		second: second ?? 0,
//		milliseconds: milliseconds,
//		timeZoneOffset: timeZoneOffset
//	)
//}
//
//func dateWithBytes(bytes: String) -> Date? {
//	guard !bytes.isEmpty else { return nil }
//
//	if bytes.range(of: "-") != nil {
//		return parseW3C(bytes: bytes)
//	}
//	return parsePubDate(bytes: bytes)
//}
