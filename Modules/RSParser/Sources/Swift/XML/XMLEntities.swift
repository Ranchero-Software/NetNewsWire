//
//  XMLEntities.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

import Foundation

// Entity decoding for the XML SAX parser.
//
// "Predefined XML entities" = the five entities XML 1.0 requires every parser
// to recognize without a DTD: &amp; &lt; &gt; &quot; &apos;.
//
// Two modes:
//
// - `.normal`: used in regular character content and attribute values. Expands
//   the predefined XML entities, numeric entities (&#NNN; and &#xHH;), and all
//   HTML named entities.
//
// - `.preservePredefinedXML`: used inside CDATA sections. Leaves the predefined
//   XML entities literal (so `&amp;` stays `&amp;`) but expands numeric entities
//   and all HTML named entities. This matches how real feeds use CDATA to wrap
//   HTML content.
//
// Unknown or malformed entities pass through literally (liberal mode).

enum XMLEntities {

	/// Result of trying to decode an entity.
	struct DecodedEntity {
		/// UTF-8 bytes to emit in place of the entity reference.
		let bytes: [UInt8]
		/// Index in the input just past the closing `;`, or just past whatever
		/// bytes were consumed (e.g. malformed entity — just the `&` itself).
		let nextIndex: Int
	}

	enum Mode {
		/// Expand predefined XML entities as well as HTML named and numeric entities.
		case normal
		/// Leave predefined XML entities literal but still expand HTML named and numeric entities.
		case preservePredefinedXML
	}

	/// Attempt to decode an entity starting at the `&` in `bytes[at]`.
	/// `mode` controls whether the predefined XML entities are expanded.
	///
	/// If a valid entity is recognized, returns the decoded UTF-8 bytes and
	/// the next-index. If not, returns a DecodedEntity with a single `&` byte and
	/// the next-index advanced past the `&`, so the caller can append it
	/// literally (liberal mode).
	static func decode(bytes: [UInt8], at: Int, mode: Mode) -> DecodedEntity {
		assert(bytes[at] == .asciiAmpersand)
		let searchEnd = Swift.min(bytes.count, at + 1 + maxEntityLength)
		var semicolonIndex: Int?
		var i = at + 1
		while i < searchEnd {
			let b = bytes[i]
			if b == .asciiSemicolon {
				semicolonIndex = i
				break
			}
			// Whitespace or another `&` means we've left the entity.
			if b.isASCIIWhitespace || b == .asciiAmpersand || b == .asciiLessThan {
				break
			}
			i += 1
		}

		guard let semicolonIndex else {
			return literalAmpersand(at: at)
		}

		let nameStart = at + 1
		let nameEndExclusive = semicolonIndex
		// Empty name: the input is literally "&;" — not an entity.
		if nameStart == nameEndExclusive {
			return literalAmpersand(at: at)
		}

		// Numeric entity?
		if bytes[nameStart] == .asciiHash {
			if let result = decodeNumeric(bytes: bytes, start: nameStart + 1, end: nameEndExclusive) {
				return DecodedEntity(bytes: result, nextIndex: semicolonIndex + 1)
			}
			return literalAmpersand(at: at)
		}

		// Named entity.
		let name = bytes[nameStart..<nameEndExclusive]

		// Predefined-XML-entity short-circuit.
		if let predefined = xmlPredefinedEntity(name: name) {
			switch mode {
			case .normal:
				return DecodedEntity(bytes: predefined, nextIndex: semicolonIndex + 1)
			case .preservePredefinedXML:
				return literalAmpersand(at: at)
			}
		}

		if let html = htmlNamedEntities[asciiString(from: name)] {
			return DecodedEntity(bytes: html, nextIndex: semicolonIndex + 1)
		}

		return literalAmpersand(at: at)
	}

	// Windows-1252 extension for bytes 0x80–0x9F. From WebKit's HTMLEntityParser.
	// Also used by XMLEncoding.transcodeWindows1252, so lives here as the shared source.
	static let windowsLatin1Extension: [UInt32] = [
		0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
		0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
		0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
		0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178
	]
}

// MARK: - Private

private extension XMLEntities {

	// Cap the semicolon search at the longest recognized entity name + 1 (for `;`),
	// to avoid pathological scans on malformed input. Derived from the HTML named-entity
	// table so it adjusts automatically if a longer entity is added. The predefined XML
	// entity names and numeric-entity digit runs are always shorter than this.
	static let maxEntityLength: Int = {
		let longestName = htmlNamedEntityStrings.keys.map(\.count).max() ?? 0
		return longestName + 1
	}()

	// Shared single-byte arrays to avoid per-call allocations for the common cases.
	static let ampersandBytes: [UInt8] = [.asciiAmpersand]
	static let lessThanBytes: [UInt8] = [.asciiLessThan]
	static let greaterThanBytes: [UInt8] = [.asciiGreaterThan]
	static let doubleQuoteBytes: [UInt8] = [.asciiDoubleQuote]
	static let singleQuoteBytes: [UInt8] = [.asciiSingleQuote]

	static func literalAmpersand(at: Int) -> DecodedEntity {
		DecodedEntity(bytes: ampersandBytes, nextIndex: at + 1)
	}

	/// Decode `&#NNN;` or `&#xHH;`. `start` is just past the `#`, `end` is exclusive.
	static func decodeNumeric(bytes: [UInt8], start: Int, end: Int) -> [UInt8]? {
		guard start < end else {
			return nil
		}

		var codepoint: UInt32 = 0
		let firstByte = bytes[start]
		let isHex = (firstByte == .asciiLowerX) || (firstByte == .asciiUpperX)
		if isHex {
			// Hex. Accept `x` or `X`.
			// If the input is just `&#x;` with no digits, the loop exits without
			// incrementing `codepoint` and the `codepoint == 0` check below rejects it.
			var i = start + 1
			while i < end {
				guard let v = bytes[i].asciiHexValue else {
					return nil
				}
				codepoint = codepoint &* 16 &+ v
				if codepoint > 0x10FFFF {
					return nil
				}
				i += 1
			}
		} else {
			// Decimal.
			var i = start
			while i < end {
				let b = bytes[i]
				guard b.isASCIIDigit else {
					return nil
				}
				codepoint = codepoint &* 10 &+ UInt32(b - .ascii0)
				if codepoint > 0x10FFFF {
					return nil
				}
				i += 1
			}
		}

		// Remap Windows-1252 extension codepoints. WebKit's HTMLEntityParser does this
		// because historical HTML authors used `&#128;` etc. expecting Windows-1252
		// characters. Applied in HTML parsing; XML parsing in practice needs this too
		// for the same authors.
		//
		// Example: `&#128;` → U+0080 (a C1 control character — unprintable) in strict
		// Unicode, but in Windows-1252 byte 0x80 is €. Authors typed `&#128;`
		// intending €, so we remap to U+20AC. Same story for `&#133;` → U+2026 (…),
		// `&#146;` → U+2019 (’), etc.
		//
		// The mask `~0x1F` checks "upper bits are 0b100" — i.e. codepoint is in
		// [0x80, 0x9F], the Windows-1252 extension range.
		if (codepoint & ~0x1F) == 0x80 {
			codepoint = windowsLatin1Extension[Int(codepoint - 0x80)]
		}

		// Post-remap, `codepoint` can't exceed 0x10FFFF — the Windows-1252 table
		// only contains values ≤ 0x20AC, and the pre-remap upper bound was already
		// enforced inside the digit loops.
		if codepoint == 0 {
			return nil
		}
		// Surrogates are not valid code points.
		if codepoint >= 0xD800 && codepoint <= 0xDFFF {
			return nil
		}

		return utf8Bytes(forCodepoint: codepoint)
	}

	/// Encode a Unicode scalar as UTF-8 bytes.
	static func utf8Bytes(forCodepoint codepoint: UInt32) -> [UInt8] {
		// 1-byte: ASCII (U+0000–U+007F).
		if codepoint < 0x80 {
			return [UInt8(codepoint)]
		}
		// 2-byte: U+0080–U+07FF (Latin-1 Supplement through most Arabic).
		if codepoint < 0x800 {
			return [
				UInt8(0xC0 | (codepoint >> 6)),
				UInt8(0x80 | (codepoint & 0x3F))
			]
		}
		// 3-byte: U+0800–U+FFFF (most of the BMP — CJK, symbols, punctuation).
		if codepoint < 0x10000 {
			return [
				UInt8(0xE0 | (codepoint >> 12)),
				UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
				UInt8(0x80 | (codepoint & 0x3F))
			]
		}
		// 4-byte: U+10000–U+10FFFF (emoji, rare scripts, supplementary planes).
		return [
			UInt8(0xF0 | (codepoint >> 18)),
			UInt8(0x80 | ((codepoint >> 12) & 0x3F)),
			UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
			UInt8(0x80 | (codepoint & 0x3F))
		]
	}

	static func xmlPredefinedEntity(name: ArraySlice<UInt8>) -> [UInt8]? {
		if name.equals("amp") {
			return ampersandBytes
		}
		if name.equals("lt") {
			return lessThanBytes
		}
		if name.equals("gt") {
			return greaterThanBytes
		}
		if name.equals("quot") {
			return doubleQuoteBytes
		}
		if name.equals("apos") {
			return singleQuoteBytes
		}
		return nil
	}

	static func asciiString(from slice: ArraySlice<UInt8>) -> String {
		// Entity names are short (≤ ~15 bytes in practice), so the String usually
		// fits in Swift's inline small-string representation and doesn't hit the heap.
		String(decoding: slice, as: UTF8.self)
	}

	// HTML named entities commonly seen in RSS and Atom feeds.
	// Matches the table in NSString+RSParser.m so behavior is identical to the old path.
	// Values are pre-encoded to UTF-8 bytes at init so lookup doesn't build a fresh
	// [UInt8] from a String per hit.
	static let htmlNamedEntities: [String: [UInt8]] = htmlNamedEntityStrings
		.mapValues { Array($0.utf8) }

	static let htmlNamedEntityStrings: [String: String] = [
		"AElig": "Æ",
		"Aacute": "Á",
		"Acirc": "Â",
		"Agrave": "À",
		"Aring": "Å",
		"Atilde": "Ã",
		"Auml": "Ä",
		"Ccedil": "Ç",
		"Dstrok": "Ð",
		"ETH": "Ð",
		"Eacute": "É",
		"Ecirc": "Ê",
		"Egrave": "È",
		"Euml": "Ë",
		"Iacute": "Í",
		"Icirc": "Î",
		"Igrave": "Ì",
		"Iuml": "Ï",
		"Ntilde": "Ñ",
		"Oacute": "Ó",
		"Ocirc": "Ô",
		"Ograve": "Ò",
		"Oslash": "Ø",
		"Otilde": "Õ",
		"Ouml": "Ö",
		"Pi": "Π",
		"THORN": "Þ",
		"Uacute": "Ú",
		"Ucirc": "Û",
		"Ugrave": "Ù",
		"Uuml": "Ü",
		"Yacute": "Y",
		"aacute": "á",
		"acirc": "â",
		"acute": "´",
		"aelig": "æ",
		"agrave": "à",
		"aring": "å",
		"atilde": "ã",
		"auml": "ä",
		"brkbar": "¦",
		"brvbar": "¦",
		"ccedil": "ç",
		"cedil": "¸",
		"cent": "¢",
		"copy": "©",
		"CounterClockwiseContourIntegral": "∳",
		"curren": "¤",
		"deg": "°",
		"die": "¨",
		"divide": "÷",
		"eacute": "é",
		"ecirc": "ê",
		"egrave": "è",
		"eth": "ð",
		"euml": "ë",
		"euro": "€",
		"frac12": "½",
		"frac14": "¼",
		"frac34": "¾",
		"hearts": "♥",
		"hellip": "…",
		"iacute": "í",
		"icirc": "î",
		"iexcl": "¡",
		"igrave": "ì",
		"iquest": "¿",
		"iuml": "ï",
		"laquo": "«",
		"ldquo": "“",
		"lsquo": "‘",
		"macr": "¯",
		"mdash": "—",
		"micro": "µ",
		"middot": "·",
		"ndash": "–",
		"not": "¬",
		"ntilde": "ñ",
		"oacute": "ó",
		"ocirc": "ô",
		"ograve": "ò",
		"ordf": "ª",
		"ordm": "º",
		"oslash": "ø",
		"otilde": "õ",
		"ouml": "ö",
		"para": "¶",
		"pi": "π",
		"plusmn": "±",
		"pound": "£",
		"raquo": "»",
		"rdquo": "”",
		"reg": "®",
		"rsquo": "’",
		"sect": "§",
		"smallcircle": "◦",
		"shy": "\u{00AD}", // U+00AD SOFT HYPHEN — invisible, so keep escaped
		"sup1": "¹",
		"sup2": "²",
		"sup3": "³",
		"szlig": "ß",
		"thorn": "þ",
		"times": "×",
		"trade": "™",
		"uacute": "ú",
		"ucirc": "û",
		"ugrave": "ù",
		"uml": "¨",
		"uuml": "ü",
		"yacute": "y",
		"yen": "¥",
		"yuml": "ÿ",
		"infin": "∞",
		"nbsp": "\u{00A0}" // U+00A0 NO-BREAK SPACE — looks like plain space, so keep escaped
	]
}
