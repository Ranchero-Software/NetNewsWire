//
//  XMLASCII.swift
//  RSParser
//
//  Created by Brent Simmons on 4/18/26.
//

// ASCII byte constants used throughout the XML scanner.

extension UInt8 {

	// Whitespace
	static let asciiTab = UInt8(ascii: "\t")
	static let asciiNewline = UInt8(ascii: "\n")
	static let asciiCarriageReturn = UInt8(ascii: "\r")
	static let asciiSpace = UInt8(ascii: " ")

	// Markup
	static let asciiExclamation = UInt8(ascii: "!")
	static let asciiDoubleQuote = UInt8(ascii: "\"")
	static let asciiHash = UInt8(ascii: "#")
	static let asciiAmpersand = UInt8(ascii: "&")
	static let asciiSingleQuote = UInt8(ascii: "'")
	static let asciiHyphen = UInt8(ascii: "-")
	static let asciiDot = UInt8(ascii: ".")
	static let asciiSlash = UInt8(ascii: "/")
	static let asciiColon = UInt8(ascii: ":")
	static let asciiSemicolon = UInt8(ascii: ";")
	static let asciiLessThan = UInt8(ascii: "<")
	static let asciiEquals = UInt8(ascii: "=")
	static let asciiGreaterThan = UInt8(ascii: ">")
	static let asciiQuestion = UInt8(ascii: "?")
	static let asciiLeftBracket = UInt8(ascii: "[")
	static let asciiRightBracket = UInt8(ascii: "]")
	static let asciiUnderscore = UInt8(ascii: "_")

	// Digits and letter ranges
	static let ascii0 = UInt8(ascii: "0")
	static let ascii9 = UInt8(ascii: "9")
	static let asciiUpperA = UInt8(ascii: "A")
	static let asciiUpperX = UInt8(ascii: "X")
	static let asciiUpperZ = UInt8(ascii: "Z")
	static let asciiLowerA = UInt8(ascii: "a")
	static let asciiLowerF = UInt8(ascii: "f")
	static let asciiLowerX = UInt8(ascii: "x")
	static let asciiLowerZ = UInt8(ascii: "z")

	var isASCIIWhitespace: Bool {
		self == .asciiSpace || self == .asciiTab || self == .asciiNewline || self == .asciiCarriageReturn
	}

	var isASCIIDigit: Bool {
		self >= .ascii0 && self <= .ascii9
	}

	var isASCIILetter: Bool {
		(self >= .asciiUpperA && self <= .asciiUpperZ) || (self >= .asciiLowerA && self <= .asciiLowerZ)
	}

	/// Returns the numeric value of a hex digit, or nil if not a hex digit.
	var asciiHexValue: UInt32? {
		if isASCIIDigit {
			return UInt32(self - .ascii0)
		}
		// `| 0x20` folds A-F to a-f; non-letters can't land in [a, f] via this OR,
		// so a single range check covers both cases.
		let lower = self | 0x20
		if lower >= .asciiLowerA && lower <= .asciiLowerF {
			return UInt32(lower - .asciiLowerA) + 10
		}
		return nil
	}

	/// Lowercased ASCII letter. Non-letters returned unchanged.
	/// `| 0x20` is the classic ASCII case-fold bit — flipping it turns 'A' into 'a'.
	var asciiLowercased: UInt8 {
		isASCIILetter ? self | 0x20 : self
	}

	/// XML Name start characters (ASCII subset).
	/// Full XML allows more Unicode, but in practice every feed in the wild uses ASCII names.
	var isXMLNameStart: Bool {
		isASCIILetter || self == .asciiUnderscore || self == .asciiColon
	}

	/// XML Name characters after the first. ASCII subset.
	var isXMLNameChar: Bool {
		isXMLNameStart || isASCIIDigit || self == .asciiHyphen || self == .asciiDot
	}
}

// MARK: - ArraySlice<UInt8>

extension ArraySlice where Element == UInt8 {

	/// Compare the slice byte-for-byte with an ASCII literal.
	func equals(_ ascii: StaticString) -> Bool {
		let byteCount = ascii.utf8CodeUnitCount
		guard count == byteCount else {
			return false
		}
		return withUnsafeBufferPointer { selfPtr in
			ascii.withUTF8Buffer { literalPtr in
				for i in 0..<byteCount {
					if selfPtr[i] != literalPtr[i] {
						return false
					}
				}
				return true
			}
		}
	}

	/// Case-insensitive ASCII comparison against a StaticString literal.
	/// The literal must be lowercase ASCII.
	func equalsASCIICaseInsensitive(lowercaseLiteral ascii: StaticString) -> Bool {
		let byteCount = ascii.utf8CodeUnitCount
		guard count == byteCount else {
			return false
		}
		return withUnsafeBufferPointer { selfPtr in
			ascii.withUTF8Buffer { literalPtr in
				#if DEBUG
				for i in 0..<byteCount {
					assert(literalPtr[i] < 0x41 || literalPtr[i] > 0x5A,
					       "equalsASCIICaseInsensitive requires a lowercase literal")
				}
				#endif
				for i in 0..<byteCount {
					if selfPtr[i].asciiLowercased != literalPtr[i] {
						return false
					}
				}
				return true
			}
		}
	}
}
