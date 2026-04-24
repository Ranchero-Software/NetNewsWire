//
//  DateParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation

/// Handles common web date formats — RFC 822 (RSS pubDate) and W3C/ISO 8601
/// (Atom and JSON Feed). Liberal: given garbage, it returns something, possibly
/// wrong. Meant for feed parsing where formatting is often sloppy.
///
/// Usage:
///
///     DateParser.date(from: "Fri, 28 May 2010 21:03:38 GMT")
///     DateParser.date(bytes: slice) // Used by the feed parsers
public enum DateParser {

	/// Parse a date string. Returns nil for empty input.
	public static func date(from dateString: String) -> Date? {
		let bytes = Array(dateString.utf8)
		return date(bytes: bytes[...])
	}

	/// Parse a date from an `ArraySlice<UInt8>` — fastest path for the feed parsers.
	static func date(bytes slice: ArraySlice<UInt8>) -> Date? {
		let count = slice.count
		guard count >= 6 && count <= 150 else {
			return nil
		}
		if looksLikeW3CDate(slice) {
			return parseW3CDate(slice)
		}
		if looksLikePubDate(slice) {
			return parsePubDate(slice)
		}
		// Fallback: try W3C.
		return parseW3CDate(slice)
	}

	// MARK: - Time zone table
	//
	// Keyed by `UInt64` holding up to 5 lowercase ASCII bytes, little-endian: byte 0
	// in the low 8 bits, byte 1 in the next 8, and so on. Direct lookup, no string
	// allocation.
	// See http://en.wikipedia.org/wiki/List_of_time_zone_abbreviations

	private static let gmtPacked: UInt64 = packASCII("gmt")
	private static let utcPacked: UInt64 = packASCII("utc")

	private static let timeZoneOffsets: [UInt64: Int] = [
		packASCII("pdt"): offset(-7),       packASCII("pst"): offset(-8),
		packASCII("est"): offset(-5),       packASCII("edt"): offset(-4),
		packASCII("mdt"): offset(-6),       packASCII("mst"): offset(-7),
		packASCII("cst"): offset(-6),       packASCII("cdt"): offset(-5),
		packASCII("act"): offset(-8),       packASCII("aft"): offset(4, 30),
		packASCII("amt"): offset(4),        packASCII("art"): offset(-3),
		packASCII("ast"): offset(3),        packASCII("azt"): offset(4),
		packASCII("bit"): offset(-12),      packASCII("bdt"): offset(8),
		packASCII("acst"): offset(9, 30),   packASCII("aest"): offset(10),
		packASCII("akst"): offset(-9),      packASCII("amst"): offset(5),
		packASCII("awst"): offset(8),       packASCII("azost"): offset(-1),
		packASCII("biot"): offset(6),       packASCII("brt"): offset(-3),
		packASCII("bst"): offset(6),        packASCII("btt"): offset(6),
		packASCII("cat"): offset(2),        packASCII("cct"): offset(6, 30),
		packASCII("cet"): offset(1),        packASCII("cest"): offset(2),
		packASCII("chast"): offset(12, 45), packASCII("chst"): offset(10),
		packASCII("cist"): offset(-8),      packASCII("ckt"): offset(-10),
		packASCII("clt"): offset(-4),       packASCII("clst"): offset(-3),
		packASCII("cot"): offset(-5),       packASCII("cost"): offset(-4),
		packASCII("cvt"): offset(-1),       packASCII("cxt"): offset(7),
		packASCII("east"): offset(-6),      packASCII("eat"): offset(3),
		packASCII("ect"): offset(-4),       packASCII("eest"): offset(3),
		packASCII("eet"): offset(2),        packASCII("fjt"): offset(12),
		packASCII("fkst"): offset(-4),      packASCII("galt"): offset(-6),
		packASCII("get"): offset(4),        packASCII("gft"): offset(-3),
		packASCII("gilt"): offset(7),       packASCII("git"): offset(-9),
		packASCII("gst"): offset(-2),       packASCII("gyt"): offset(-4),
		packASCII("hast"): offset(-10),     packASCII("hkt"): offset(8),
		packASCII("hmt"): offset(5),        packASCII("irkt"): offset(8),
		packASCII("irst"): offset(3, 30),   packASCII("ist"): offset(2),
		packASCII("jst"): offset(9),        packASCII("krat"): offset(7),
		packASCII("kst"): offset(9),        packASCII("lhst"): offset(10, 30),
		packASCII("lint"): offset(14),      packASCII("magt"): offset(11),
		packASCII("mit"): offset(-9, 30),   packASCII("msk"): offset(3),
		packASCII("mut"): offset(4),        packASCII("ndt"): offset(-2, 30),
		packASCII("nft"): offset(11, 30),   packASCII("npt"): offset(5, 45),
		packASCII("nt"): offset(-3, 30),    packASCII("omst"): offset(6),
		packASCII("pett"): offset(12),      packASCII("phot"): offset(13),
		packASCII("pkt"): offset(5),        packASCII("ret"): offset(4),
		packASCII("samt"): offset(4),       packASCII("sast"): offset(2),
		packASCII("sbt"): offset(11),       packASCII("sct"): offset(4),
		packASCII("slt"): offset(5, 30),    packASCII("sst"): offset(8),
		packASCII("taht"): offset(-10),     packASCII("tha"): offset(7),
		packASCII("uyt"): offset(-3),       packASCII("uyst"): offset(-2),
		packASCII("vet"): offset(-4, 30),   packASCII("vlat"): offset(10),
		packASCII("wat"): offset(1),        packASCII("wet"): offset(0),
		packASCII("west"): offset(1),       packASCII("yakt"): offset(9),
		packASCII("yekt"): offset(5)
	]
}

// MARK: - Private

private extension DateParser {

	// MARK: - Format sniffing

	static func looksLikePubDate(_ slice: ArraySlice<UInt8>) -> Bool {
		slice.contains { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: ",") }
	}

	static func looksLikeW3CDate(_ slice: ArraySlice<UInt8>) -> Bool {
		// Skip leading whitespace, then expect 4 digits followed by a date separator.
		// Recognizes `-` (W3C / ISO 8601) and `/` (common non-standard format such as
		// `2020/1/10 14:33:00` seen in Dvbbs.Net-generated feeds).
		for i in slice.indices {
			let b = slice[i]
			if b == UInt8(ascii: " ") || b == UInt8(ascii: "\r") || b == UInt8(ascii: "\n") || b == UInt8(ascii: "\t") {
				continue
			}
			guard slice.endIndex - i >= 5 else {
				return false
			}
			let separator = slice[i + 4]
			return isDigit(slice[i])
				&& isDigit(slice[i + 1])
				&& isDigit(slice[i + 2])
				&& isDigit(slice[i + 3])
				&& (separator == UInt8(ascii: "-") || separator == UInt8(ascii: "/"))
		}
		return false
	}

	// MARK: - PubDate (RFC 822 / 2822)

	static func parsePubDate(_ slice: ArraySlice<UInt8>) -> Date? {
		var finalIndex = slice.startIndex

		var day = nextNumericValue(slice, startingIndex: slice.startIndex, maxDigits: 2, finalIndex: &finalIndex)
		if day == nil || day! < 1 {
			day = 1
		}

		let month = nextMonthValue(slice, startingIndex: finalIndex + 1, finalIndex: &finalIndex) ?? 1

		var year = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 4, finalIndex: &finalIndex)
		if let y = year, y < 100 {
			year = y + 2000
		}

		var hour = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		if hour < 0 { hour = 0 }

		var minute = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		if minute < 0 { minute = 0 }

		var currentIndex = finalIndex + 1
		let hasSeconds = currentIndex < slice.endIndex && slice[currentIndex] == UInt8(ascii: ":")
		var second = 0
		if hasSeconds {
			second = nextNumericValue(slice, startingIndex: currentIndex, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		}

		currentIndex = finalIndex + 1
		let hasTimeZone = currentIndex < slice.endIndex && slice[currentIndex] == UInt8(ascii: " ")
		var timeZoneOffset = 0
		if hasTimeZone {
			timeZoneOffset = parsedTimeZoneOffset(slice, startingIndex: currentIndex)
		}

		return dateWithComponents(year: year ?? 1970, month: month, day: day!, hour: hour, minute: minute, second: second, milliseconds: 0, timeZoneOffset: timeZoneOffset)
	}

	// MARK: - W3C / ISO 8601

	static func parseW3CDate(_ slice: ArraySlice<UInt8>) -> Date? {
		var finalIndex = slice.startIndex

		let year = nextNumericValue(slice, startingIndex: slice.startIndex, maxDigits: 4, finalIndex: &finalIndex) ?? 1970
		let month = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 1
		let day = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 1
		let hour = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		let minute = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		let second = nextNumericValue(slice, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0

		var currentIndex = finalIndex + 1
		var milliseconds = 0
		let hasMilliseconds = currentIndex < slice.endIndex && slice[currentIndex] == UInt8(ascii: ".")
		if hasMilliseconds {
			milliseconds = nextNumericValue(slice, startingIndex: currentIndex, maxDigits: 3, finalIndex: &finalIndex) ?? 0
			currentIndex = finalIndex + 1
			while currentIndex < slice.endIndex && isDigit(slice[currentIndex]) {
				currentIndex += 1
			}
		}

		let timeZoneOffset = parsedTimeZoneOffset(slice, startingIndex: currentIndex)
		return dateWithComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second, milliseconds: milliseconds, timeZoneOffset: timeZoneOffset)
	}

	// MARK: - Components → Date

	/// Convert broken-down UTC date/time components to a `Date` using Howard Hinnant's
	/// days-from-civil algorithm. Pure integer arithmetic — no `timegm` call, no Foundation
	/// calendar lookup, portable to any platform.
	/// See: https://howardhinnant.github.io/date_algorithms.html
	static func dateWithComponents(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, milliseconds: Int, timeZoneOffset: Int) -> Date {
		// Hinnant treats years as starting in March so that Feb (with its variable length)
		// is the last month of the year — simplifies day-of-year math. Jan/Feb of year Y
		// are treated as months 13/14 of year Y-1.
		let shiftedYear = (month <= 2) ? year - 1 : year
		let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
		let yearOfEra = shiftedYear - era * 400                              // [0, 399]
		let shiftedMonth = month > 2 ? month - 3 : month + 9                 // [0, 11]
		let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1               // [0, 365]
		let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear  // [0, 146096]
		let daysSinceEpoch = era * 146097 + dayOfEra - 719468

		let epochSeconds = daysSinceEpoch * 86400 + hour * 3600 + minute * 60 + second - timeZoneOffset
		var interval = TimeInterval(epochSeconds)
		if milliseconds > 0 {
			interval += TimeInterval(milliseconds) / 1000.0
		}
		return Date(timeIntervalSince1970: interval)
	}

	// MARK: - Numeric and alphabetic scanning

	@inline(__always)
	static func isDigit(_ b: UInt8) -> Bool {
		b >= UInt8(ascii: "0") && b <= UInt8(ascii: "9")
	}

	@inline(__always)
	static func isAlpha(_ b: UInt8) -> Bool {
		(b >= UInt8(ascii: "A") && b <= UInt8(ascii: "Z"))
			|| (b >= UInt8(ascii: "a") && b <= UInt8(ascii: "z"))
	}

	/// Consume up to `maxDigits` digits starting at `startingIndex`, skipping leading
	/// non-digits. Returns the accumulated integer value, or nil if no digits found.
	/// `finalIndex` is set to the position of the last character examined.
	///
	/// Two-phase: skip leading non-digits, then accumulate digits. Avoids a per-iteration
	/// branch in the hot digit-reading phase and is easier to read.
	static func nextNumericValue(_ slice: ArraySlice<UInt8>, startingIndex: Int, maxDigits: Int, finalIndex: inout Int) -> Int? {
		let limit = maxDigits > 4 ? 4 : maxDigits
		let end = slice.endIndex
		var i = startingIndex

		// Phase 1: skip leading non-digits.
		while i < end {
			if isDigit(slice[i]) {
				break
			}
			finalIndex = i
			i += 1
		}
		if i >= end {
			return nil
		}

		// Phase 2: accumulate digits (we know slice[i] is a digit on entry).
		var value = 0
		var digitsRead = 0
		while i < end {
			let b = slice[i]
			if !isDigit(b) {
				break
			}
			value = value * 10 + Int(b - UInt8(ascii: "0"))
			digitsRead += 1
			finalIndex = i
			i += 1
			if digitsRead >= limit {
				break
			}
		}
		return value
	}

	/// Consume up to three alphabetic characters and interpret as a month number (1–12).
	/// Zero-allocation: three `UInt8` locals live on the stack (or in registers).
	static func nextMonthValue(_ slice: ArraySlice<UInt8>, startingIndex: Int, finalIndex: inout Int) -> Int? {
		var c0: UInt8 = 0
		var c1: UInt8 = 0
		var c2: UInt8 = 0
		var charsRead = 0

		var i = startingIndex
		while i < slice.endIndex {
			finalIndex = i
			let b = slice[i]
			if !isAlpha(b) {
				if charsRead == 0 {
					i += 1
					continue
				}
				break
			}

			let lower = b | 0x20

			// First character is often enough: F/S/O/N/D are unambiguous.
			if charsRead == 0 {
				switch lower {
				case UInt8(ascii: "f"): return 2
				case UInt8(ascii: "s"): return 9
				case UInt8(ascii: "o"): return 10
				case UInt8(ascii: "n"): return 11
				case UInt8(ascii: "d"): return 12
				default: break
				}
				c0 = lower
			} else if charsRead == 1 {
				c1 = lower
			} else {
				c2 = lower
			}

			charsRead += 1
			if charsRead >= 3 {
				break
			}
			i += 1
		}

		if charsRead < 2 {
			return nil
		}

		switch c0 {
		case UInt8(ascii: "j"):
			if c1 == UInt8(ascii: "a") {
				return 1 // Jan
			}
			if c1 == UInt8(ascii: "u") {
				if charsRead >= 3 && c2 == UInt8(ascii: "n") {
					return 6 // Jun
				}
				return 7 // Jul
			}
			return 1 // Defensive: "Jx" → Jan
		case UInt8(ascii: "m"):
			if charsRead >= 3 && c2 == UInt8(ascii: "y") {
				return 5 // May
			}
			return 3 // Mar
		case UInt8(ascii: "a"):
			if c1 == UInt8(ascii: "u") {
				return 8 // Aug
			}
			return 4 // Apr
		default:
			return 1
		}
	}

	// MARK: - Time zones

	/// Parse a timezone spec starting at `startingIndex`. Returns the offset in seconds.
	/// Liberal: returns 0 if no timezone, Z, GMT, or UTC; otherwise either looks up
	/// an abbreviation (alpha path) or reads a signed numeric offset (numeric path).
	///
	/// The first non-whitespace/colon byte decides the path — numeric offsets
	/// (the common case in real feeds) skip the packing/hashing overhead entirely.
	static func parsedTimeZoneOffset(_ slice: ArraySlice<UInt8>, startingIndex: Int) -> Int {
		// Skip leading whitespace and colons.
		var i = startingIndex
		while i < slice.endIndex {
			let b = slice[i]
			if b == UInt8(ascii: " ") || b == UInt8(ascii: ":") {
				i += 1
				continue
			}
			break
		}
		if i >= slice.endIndex {
			return 0
		}

		let first = slice[i]
		// `Z` means UTC.
		if first == UInt8(ascii: "z") || first == UInt8(ascii: "Z") {
			return 0
		}
		if first == UInt8(ascii: "+") || first == UInt8(ascii: "-") {
			return parseNumericTimeZoneOffset(slice, startingIndex: i)
		}
		if isAlpha(first) {
			return lookupAlphaTimeZone(slice, startingIndex: i)
		}
		return 0
	}

	/// Numeric-offset path: `+HHMM`, `-HHMM`, `+HH:MM`, `+HH`, etc.
	/// Caller guarantees `slice[startingIndex]` is `+` or `-`.
	static func parseNumericTimeZoneOffset(_ slice: ArraySlice<UInt8>, startingIndex: Int) -> Int {
		let isPlus = slice[startingIndex] == UInt8(ascii: "+")
		let end = slice.endIndex
		var i = startingIndex + 1

		// Up to 2 hour digits.
		var hours = 0
		var hoursRead = 0
		while i < end && hoursRead < 2 {
			let b = slice[i]
			if !isDigit(b) {
				break
			}
			hours = hours * 10 + Int(b - UInt8(ascii: "0"))
			hoursRead += 1
			i += 1
		}

		// Optional `:` or ` ` separator between hours and minutes.
		if i < end && (slice[i] == UInt8(ascii: ":") || slice[i] == UInt8(ascii: " ")) {
			i += 1
		}

		// Up to 2 minute digits.
		var minutes = 0
		var minutesRead = 0
		while i < end && minutesRead < 2 {
			let b = slice[i]
			if !isDigit(b) {
				break
			}
			minutes = minutes * 10 + Int(b - UInt8(ascii: "0"))
			minutesRead += 1
			i += 1
		}

		if hours == 0 && minutes == 0 {
			return 0
		}
		let seconds = hours * 3600 + minutes * 60
		return isPlus ? seconds : -seconds
	}

	/// Alphabetic-offset path: 2-5 letter timezone abbreviations (GMT, EST, CEST, …).
	/// Caller guarantees `slice[startingIndex]` is alphabetic.
	static func lookupAlphaTimeZone(_ slice: ArraySlice<UInt8>, startingIndex: Int) -> Int {
		var packed: UInt64 = 0
		var charsRead = 0

		var i = startingIndex
		while i < slice.endIndex && charsRead < 5 {
			let b = slice[i]
			if isAlpha(b) {
				packed |= UInt64(b | 0x20) << (charsRead * 8)
				charsRead += 1
				i += 1
				continue
			}
			if b == UInt8(ascii: ":") || b == UInt8(ascii: " ") {
				i += 1
				continue
			}
			break
		}

		if charsRead == 0 {
			return 0
		}
		// "gmt" and "utc" both → 0.
		if packed == gmtPacked || packed == utcPacked {
			return 0
		}
		return timeZoneOffsets[packed] ?? 0
	}

	// MARK: - Table construction helpers

	/// Pack a short ASCII literal (up to 8 bytes) into a UInt64, lowercasing uppercase
	/// letters. Non-ASCII bytes are treated as-is.
	static func packASCII(_ s: StaticString) -> UInt64 {
		var result: UInt64 = 0
		s.withUTF8Buffer { buf in
			let count = Swift.min(buf.count, 8)
			for i in 0..<count {
				result |= UInt64(buf[i] | 0x20) << (i * 8)
			}
		}
		return result
	}

	@inline(__always)
	static func offset(_ hours: Int, _ minutes: Int = 0) -> Int {
		if hours < 0 {
			return hours * 3600 - minutes * 60
		}
		return hours * 3600 + minutes * 60
	}
}
