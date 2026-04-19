//
//  DateParser.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation

// Pure-Swift port of the old RSDateParser.m.
//
// Handles common web date formats — RFC 822 (RSS pubDate) and W3C/ISO 8601
// (Atom and JSON Feed). Liberal: given garbage, it returns something, possibly
// wrong. Meant for feed parsing where formatting is often sloppy.
//
// Zero-allocation per parse on the hot path: numeric accumulation is inline,
// the month scan uses stack locals, and the time zone table is keyed by
// packed lowercase ASCII bytes (UInt64).
//
// Usage:
//   DateParser.date(from: "Fri, 28 May 2010 21:03:38 GMT")
//   DateParser.date(bytes: slice)   // the hot path for the feed parsers

public enum DateParser {

	/// Parse a date string. Returns nil for empty input.
	public static func date(from dateString: String) -> Date? {
		// Try the zero-copy path first.
		if let d = dateString.utf8.withContiguousStorageIfAvailable({ buf in
			date(buffer: buf)
		}) {
			return d
		}
		// Fallback: make a contiguous array.
		let bytes = Array(dateString.utf8)
		return bytes.withUnsafeBufferPointer { buf in
			date(buffer: buf)
		}
	}

	/// Parse a date from a raw byte pointer + length (UTF-8 / ASCII).
	public static func date(bytes: UnsafePointer<UInt8>?, count: Int) -> Date? {
		guard let bytes else {
			return nil
		}
		let buffer = UnsafeBufferPointer(start: bytes, count: count)
		return date(buffer: buffer)
	}

	/// Parse a date from an `ArraySlice<UInt8>` — the hot path for the feed parsers.
	static func date(bytes slice: ArraySlice<UInt8>) -> Date? {
		slice.withContiguousStorageIfAvailable { buffer in
			date(buffer: buffer)
		} ?? date(buffer: UnsafeBufferPointer(start: nil, count: 0))
	}

	// MARK: - Core

	private static func date(buffer: UnsafeBufferPointer<UInt8>) -> Date? {
		let count = buffer.count
		guard count >= 6 && count <= 150 else {
			return nil
		}
		if looksLikeW3CDate(buffer) {
			return parseW3CDate(buffer)
		}
		if looksLikePubDate(buffer) {
			return parsePubDate(buffer)
		}
		// Fallback: try W3C.
		return parseW3CDate(buffer)
	}

	// MARK: - Format sniffing

	private static func looksLikePubDate(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool {
		for b in buffer where b == UInt8(ascii: " ") || b == UInt8(ascii: ",") {
			return true
		}
		return false
	}

	private static func looksLikeW3CDate(_ buffer: UnsafeBufferPointer<UInt8>) -> Bool {
		// Skip leading whitespace, then expect 4 digits followed by `-`.
		for i in 0..<buffer.count {
			let b = buffer[i]
			if b == UInt8(ascii: " ") || b == UInt8(ascii: "\r") || b == UInt8(ascii: "\n") || b == UInt8(ascii: "\t") {
				continue
			}
			guard buffer.count - i >= 5 else {
				return false
			}
			return isDigit(buffer[i])
				&& isDigit(buffer[i + 1])
				&& isDigit(buffer[i + 2])
				&& isDigit(buffer[i + 3])
				&& buffer[i + 4] == UInt8(ascii: "-")
		}
		return false
	}

	// MARK: - PubDate (RFC 822 / 2822)

	private static func parsePubDate(_ buffer: UnsafeBufferPointer<UInt8>) -> Date? {
		var finalIndex = 0
		let count = buffer.count

		var day = nextNumericValue(buffer, startingIndex: 0, maxDigits: 2, finalIndex: &finalIndex)
		if day == nil || day! < 1 {
			day = 1
		}

		let month = nextMonthValue(buffer, startingIndex: finalIndex + 1, finalIndex: &finalIndex) ?? 1

		var year = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 4, finalIndex: &finalIndex)
		if let y = year, y < 100 {
			year = y + 2000
		}

		var hour = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		if hour < 0 { hour = 0 }

		var minute = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		if minute < 0 { minute = 0 }

		var currentIndex = finalIndex + 1
		let hasSeconds = currentIndex < count && buffer[currentIndex] == UInt8(ascii: ":")
		var second = 0
		if hasSeconds {
			second = nextNumericValue(buffer, startingIndex: currentIndex, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		}

		currentIndex = finalIndex + 1
		let hasTimeZone = currentIndex < count && buffer[currentIndex] == UInt8(ascii: " ")
		var timeZoneOffset = 0
		if hasTimeZone {
			timeZoneOffset = parsedTimeZoneOffset(buffer, startingIndex: currentIndex)
		}

		return dateWithComponents(year: year ?? 1970, month: month, day: day!, hour: hour, minute: minute, second: second, milliseconds: 0, timeZoneOffset: timeZoneOffset)
	}

	// MARK: - W3C / ISO 8601

	private static func parseW3CDate(_ buffer: UnsafeBufferPointer<UInt8>) -> Date? {
		var finalIndex = 0
		let count = buffer.count

		let year = nextNumericValue(buffer, startingIndex: 0, maxDigits: 4, finalIndex: &finalIndex) ?? 1970
		let month = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 1
		let day = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 1
		let hour = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		let minute = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0
		let second = nextNumericValue(buffer, startingIndex: finalIndex + 1, maxDigits: 2, finalIndex: &finalIndex) ?? 0

		var currentIndex = finalIndex + 1
		var milliseconds = 0
		let hasMilliseconds = currentIndex < count && buffer[currentIndex] == UInt8(ascii: ".")
		if hasMilliseconds {
			milliseconds = nextNumericValue(buffer, startingIndex: currentIndex, maxDigits: 3, finalIndex: &finalIndex) ?? 0
			currentIndex = finalIndex + 1
			while currentIndex < count && isDigit(buffer[currentIndex]) {
				currentIndex += 1
			}
		}

		let timeZoneOffset = parsedTimeZoneOffset(buffer, startingIndex: currentIndex)
		return dateWithComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second, milliseconds: milliseconds, timeZoneOffset: timeZoneOffset)
	}

	// MARK: - Components → Date

	/// Convert broken-down UTC date/time components to a `Date` using Howard Hinnant's
	/// days-from-civil algorithm. Pure integer arithmetic — no `timegm` call, no Foundation
	/// calendar lookup, portable to any platform.
	/// See: https://howardhinnant.github.io/date_algorithms.html
	private static func dateWithComponents(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, milliseconds: Int, timeZoneOffset: Int) -> Date {
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
	private static func isDigit(_ b: UInt8) -> Bool {
		b >= UInt8(ascii: "0") && b <= UInt8(ascii: "9")
	}

	@inline(__always)
	private static func isAlpha(_ b: UInt8) -> Bool {
		(b >= UInt8(ascii: "A") && b <= UInt8(ascii: "Z"))
			|| (b >= UInt8(ascii: "a") && b <= UInt8(ascii: "z"))
	}

	/// Consume up to `maxDigits` digits starting at `startingIndex`, skipping leading
	/// non-digits. Returns the accumulated integer value, or nil if no digits found.
	/// `finalIndex` is set to the position of the last character examined.
	///
	/// Two-phase: skip leading non-digits, then accumulate digits. Avoids a per-iteration
	/// branch in the hot digit-reading phase and is easier to read.
	private static func nextNumericValue(_ buffer: UnsafeBufferPointer<UInt8>, startingIndex: Int, maxDigits: Int, finalIndex: inout Int) -> Int? {
		let limit = maxDigits > 4 ? 4 : maxDigits
		let count = buffer.count
		var i = startingIndex

		// Phase 1: skip leading non-digits.
		while i < count {
			if isDigit(buffer[i]) {
				break
			}
			finalIndex = i
			i += 1
		}
		if i >= count {
			return nil
		}

		// Phase 2: accumulate digits (we know buffer[i] is a digit on entry).
		var value = 0
		var digitsRead = 0
		while i < count {
			let b = buffer[i]
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
	/// Zero-allocation: uses `UInt32` to pack up to 3 bytes (lowercased).
	private static func nextMonthValue(_ buffer: UnsafeBufferPointer<UInt8>, startingIndex: Int, finalIndex: inout Int) -> Int? {
		var packed: UInt32 = 0
		var charsRead = 0

		var i = startingIndex
		while i < buffer.count {
			finalIndex = i
			let b = buffer[i]
			if !isAlpha(b) {
				if charsRead == 0 {
					i += 1
					continue
				}
				break
			}

			// First character is often enough: F/S/O/N/D are unambiguous.
			if charsRead == 0 {
				switch b | 0x20 {
				case UInt8(ascii: "f"): return 2
				case UInt8(ascii: "s"): return 9
				case UInt8(ascii: "o"): return 10
				case UInt8(ascii: "n"): return 11
				case UInt8(ascii: "d"): return 12
				default: break
				}
			}

			packed |= UInt32(b | 0x20) << (charsRead * 8)
			charsRead += 1
			if charsRead >= 3 {
				break
			}
			i += 1
		}

		if charsRead < 2 {
			return nil
		}

		let c0 = UInt8(packed & 0xFF)
		let c1 = UInt8((packed >> 8) & 0xFF)
		let c2 = UInt8((packed >> 16) & 0xFF)

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
	/// Liberal: returns 0 if no timezone, Z, GMT, or UTC; otherwise looks up abbreviation
	/// or parses signed numeric offset.
	///
	/// Zero-allocation: packs up to 5 lowercase ASCII bytes into a UInt64 as it scans,
	/// tracks `hasAlpha` and `firstByte` along the way.
	private static func parsedTimeZoneOffset(_ buffer: UnsafeBufferPointer<UInt8>, startingIndex: Int) -> Int {
		var packed: UInt64 = 0
		var charsRead = 0
		var hasAlpha = false
		var firstByte: UInt8 = 0

		var i = startingIndex
		while i < buffer.count && charsRead < 5 {
			let b = buffer[i]
			if b == UInt8(ascii: ":") || b == UInt8(ascii: " ") {
				i += 1
				continue
			}
			if isDigit(b) || isAlpha(b) || b == UInt8(ascii: "+") || b == UInt8(ascii: "-") {
				let lower = b | 0x20
				if charsRead == 0 {
					firstByte = lower
				}
				if isAlpha(b) {
					hasAlpha = true
				}
				packed |= UInt64(lower) << (charsRead * 8)
				charsRead += 1
			}
			i += 1
		}

		if charsRead == 0 {
			return 0
		}
		// `Z` means UTC.
		if firstByte == UInt8(ascii: "z") {
			return 0
		}

		if hasAlpha {
			// "gmt" and "utc" both → 0.
			if packed == gmtPacked || packed == utcPacked {
				return 0
			}
			return timeZoneOffsets[packed] ?? 0
		}

		return offsetForSignedNumericOffset(packed: packed, charsRead: charsRead)
	}

	/// Parse `+HHMM` / `-HHMM` / `+HH` / `-HH` from packed lowercase ASCII bytes.
	private static func offsetForSignedNumericOffset(packed: UInt64, charsRead: Int) -> Int {
		guard charsRead > 0 else {
			return 0
		}
		let first = UInt8(packed & 0xFF)
		let isPlus = first == UInt8(ascii: "+")

		// Bytes at positions 1...charsRead-1 are digits (possibly). Accumulate
		// the first 2 as hours, next 2 as minutes.
		func digit(at position: Int) -> Int? {
			guard position < charsRead else {
				return nil
			}
			let b = UInt8((packed >> (position * 8)) & 0xFF)
			return isDigit(b) ? Int(b - UInt8(ascii: "0")) : nil
		}

		var hours = 0
		if let d1 = digit(at: 1), let d2 = digit(at: 2) {
			hours = d1 * 10 + d2
		} else if let d1 = digit(at: 1) {
			hours = d1
		}

		var minutes = 0
		if let d3 = digit(at: 3), let d4 = digit(at: 4) {
			minutes = d3 * 10 + d4
		} else if let d3 = digit(at: 3) {
			minutes = d3
		}

		if hours == 0 && minutes == 0 {
			return 0
		}
		let seconds = hours * 3600 + minutes * 60
		return isPlus ? seconds : -seconds
	}

	// MARK: - Time zone table
	//
	// Keyed by `UInt64` holding up to 5 lowercase ASCII bytes, little-endian: byte 0 in
	// the low 8 bits, byte 1 in the next 8, and so on. Direct lookup, no string allocation.
	// Values from the old RSDateParser.m table.
	// See http://en.wikipedia.org/wiki/List_of_time_zone_abbreviations

	private static let gmtPacked: UInt64 = packASCII("gmt")
	private static let utcPacked: UInt64 = packASCII("utc")

	/// Pack a short ASCII literal (up to 8 bytes) into a UInt64, lowercasing uppercase
	/// letters. Non-ASCII bytes are treated as-is. Compile-time foldable for literals.
	private static func packASCII(_ s: StaticString) -> UInt64 {
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
	private static func offset(_ hours: Int, _ minutes: Int = 0) -> Int {
		if hours < 0 {
			return hours * 3600 - minutes * 60
		}
		return hours * 3600 + minutes * 60
	}

	private static let timeZoneOffsets: [UInt64: Int] = [
		packASCII("pdt"): offset(-7), packASCII("pst"): offset(-8),
		packASCII("est"): offset(-5), packASCII("edt"): offset(-4),
		packASCII("mdt"): offset(-6), packASCII("mst"): offset(-7),
		packASCII("cst"): offset(-6), packASCII("cdt"): offset(-5),
		packASCII("act"): offset(-8), packASCII("aft"): offset(4, 30),
		packASCII("amt"): offset(4),  packASCII("art"): offset(-3),
		packASCII("ast"): offset(3),  packASCII("azt"): offset(4),
		packASCII("bit"): offset(-12), packASCII("bdt"): offset(8),
		packASCII("acst"): offset(9, 30), packASCII("aest"): offset(10),
		packASCII("akst"): offset(-9), packASCII("amst"): offset(5),
		packASCII("awst"): offset(8), packASCII("azost"): offset(-1),
		packASCII("biot"): offset(6), packASCII("brt"): offset(-3),
		packASCII("bst"): offset(6),  packASCII("btt"): offset(6),
		packASCII("cat"): offset(2),  packASCII("cct"): offset(6, 30),
		packASCII("cet"): offset(1),  packASCII("cest"): offset(2),
		packASCII("chast"): offset(12, 45), packASCII("chst"): offset(10),
		packASCII("cist"): offset(-8), packASCII("ckt"): offset(-10),
		packASCII("clt"): offset(-4), packASCII("clst"): offset(-3),
		packASCII("cot"): offset(-5), packASCII("cost"): offset(-4),
		packASCII("cvt"): offset(-1), packASCII("cxt"): offset(7),
		packASCII("east"): offset(-6), packASCII("eat"): offset(3),
		packASCII("ect"): offset(-4), packASCII("eest"): offset(3),
		packASCII("eet"): offset(2),  packASCII("fjt"): offset(12),
		packASCII("fkst"): offset(-4), packASCII("galt"): offset(-6),
		packASCII("get"): offset(4),  packASCII("gft"): offset(-3),
		packASCII("gilt"): offset(7), packASCII("git"): offset(-9),
		packASCII("gst"): offset(-2), packASCII("gyt"): offset(-4),
		packASCII("hast"): offset(-10), packASCII("hkt"): offset(8),
		packASCII("hmt"): offset(5),  packASCII("irkt"): offset(8),
		packASCII("irst"): offset(3, 30), packASCII("ist"): offset(2),
		packASCII("jst"): offset(9),  packASCII("krat"): offset(7),
		packASCII("kst"): offset(9),  packASCII("lhst"): offset(10, 30),
		packASCII("lint"): offset(14), packASCII("magt"): offset(11),
		packASCII("mit"): offset(-9, 30), packASCII("msk"): offset(3),
		packASCII("mut"): offset(4),  packASCII("ndt"): offset(-2, 30),
		packASCII("nft"): offset(11, 30), packASCII("npt"): offset(5, 45),
		packASCII("nt"): offset(-3, 30), packASCII("omst"): offset(6),
		packASCII("pett"): offset(12), packASCII("phot"): offset(13),
		packASCII("pkt"): offset(5),  packASCII("ret"): offset(4),
		packASCII("samt"): offset(4), packASCII("sast"): offset(2),
		packASCII("sbt"): offset(11), packASCII("sct"): offset(4),
		packASCII("slt"): offset(5, 30), packASCII("sst"): offset(8),
		packASCII("taht"): offset(-10), packASCII("tha"): offset(7),
		packASCII("uyt"): offset(-3), packASCII("uyst"): offset(-2),
		packASCII("vet"): offset(-4, 30), packASCII("vlat"): offset(10),
		packASCII("wat"): offset(1),  packASCII("wet"): offset(0),
		packASCII("west"): offset(1), packASCII("yakt"): offset(9),
		packASCII("yekt"): offset(5)
	]
}
