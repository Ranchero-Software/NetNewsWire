//
//  HTMLEntityDecoder.swift
//
//
//  Created by Brent Simmons on 9/14/24.
//

import Foundation

public final class HTMLEntityDecoder {

	public static func decodedString(_ encodedString: String) -> String {

		let scanner = EntityScanner(string: encodedString)
		var result = ""
		var didDecodeAtLeastOneEntity = false

		while true {

			let scannedString = scanner.scanUpToAmpersand()
			if !scannedString.isEmpty {
				result.append(scannedString)
			}
			if scanner.isAtEnd {
				break
			}

			let savedScanLocation = scanner.scanLocation

			if let decodedEntity = scanner.scanEntityValue() {
				result.append(decodedEntity)
				didDecodeAtLeastOneEntity = true
			}
			else {
				result.append("&")
				scanner.scanLocation = savedScanLocation + 1
			}

			if scanner.isAtEnd {
				break
			}
		}

		if !didDecodeAtLeastOneEntity { // No entities decoded?
			return encodedString
		}
		return result
	}
}

/// Purpose-built version of NSScanner, which has deprecated the parts we want to use.
final class EntityScanner {

	let string: String
	let count: Int
	var scanLocation = 0

	var isAtEnd: Bool {
		scanLocation >= count
	}

	var currentCharacter: Character? {
		guard !isAtEnd else {
			return nil
		}
		return string.characterAtIntIndex(scanLocation)
	}

	init(string: String) {
		self.string = string
		self.count = string.count
	}

	static let ampersandCharacter = Character("&")

	/// Scans up to `characterToFind` and returns the characters up to (and not including) `characterToFind`.
	/// - Returns: the scanned portion before `characterToFind`. May be empty string.
	func scanUpToAmpersand() -> String {

		let characterToFind = Self.ampersandCharacter
		var scanned = ""
		
		while true {

			guard let ch = currentCharacter else {
				break
			}
			scanLocation += 1

			if ch == characterToFind {
				break
			}
			else {
				scanned.append(ch)
			}
		}

		return scanned
	}

	static let semicolonCharacter = Character(";")

	func scanEntityValue() -> String? {

		let initialScanLocation = scanLocation
		let maxEntityLength = 20 // It’s probably smaller, but this is just for sanity.

		while true {

			guard let ch = currentCharacter else {
				break
			}
			if CharacterSet.whitespacesAndNewlines.contains(ch.unicodeScalars.first!) {
				break
			}

			if ch == Self.semicolonCharacter {
				let entityRange = initialScanLocation..<scanLocation
				guard let entity = string.substring(intRange: entityRange), let decodedEntity = decodedEntity(entity) else {
					assertionFailure("Unexpected failure scanning entity in scanEntityValue.")
					scanLocation = initialScanLocation + 1
					return nil
				}
				scanLocation = scanLocation + 1
				return decodedEntity
			}

			scanLocation += 1
			if scanLocation - initialScanLocation > maxEntityLength {
				break
			}
			if isAtEnd {
				break
			}
		}

		return nil
	}
}

extension String {

	func indexForInt(_ i: Int) -> Index? {

		index(startIndex, offsetBy: i, limitedBy: endIndex)
	}

	func characterAtIntIndex(_ i: Int) -> Character? {

		guard let index = indexForInt(i) else {
			return nil
		}

		return self[index]
	}

	func substring(intRange: Range<Int>) -> String? {

		guard let rangeLower = indexForInt(intRange.lowerBound) else {
			return nil
		}
		guard let rangeUpper = indexForInt(intRange.upperBound) else {
			return nil
		}

		return String(self[rangeLower..<rangeUpper])
	}
}

/// rawEntity may or may not have leading `&` and/or trailing `;` characters.
private func decodedEntity(_ rawEntity: String) -> String? {

	var s = rawEntity

	if s.hasPrefix("&") {
		s.removeFirst()
	}
	if s.hasSuffix(";") {
		s.removeLast()
	}

	if let decodedEntity = entitiesDictionary[s] {
		return decodedEntity
	}

	if s.hasPrefix("#x") || s.hasPrefix("#X") { // Hex
		let scanner = Scanner(string: s)
			scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#xX")
		var hexValue: UInt64 = 0
		if scanner.scanHexInt64(&hexValue) {
			return stringWithValue(UInt32(hexValue))
		}
		return nil
	}

	else if s.hasPrefix("#") {
		s.removeFirst()
		guard let value = UInt32(s), value >= 1 else {
			return nil
		}
		return stringWithValue(value)
	}

	return nil
}

private func stringWithValue(_ value: UInt32) -> String? {

	// From WebCore's HTMLEntityParser
	let windowsLatin1ExtensionArray: [UInt32] = [
		0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, // 80-87
		0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, // 88-8F
		0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, // 90-97
		0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178  // 98-9F
	]

	var modifiedValue = value

	if (modifiedValue & ~0x1F) == 0x80 { // value >= 128 && value < 160
		modifiedValue = windowsLatin1ExtensionArray[Int(modifiedValue - 0x80)]
	}

	modifiedValue = CFSwapInt32HostToLittle(modifiedValue)

	let data = Data(bytes: &modifiedValue, count: MemoryLayout.size(ofValue: modifiedValue))

	return String(data: data, encoding: .utf32LittleEndian)
}

private let entitiesDictionary =
	[
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
	"amp": "&",
	"apos": "'",
	"aring": "å",
	"atilde": "ã",
	"auml": "ä",
	"brkbar": "¦",
	"brvbar": "¦",
	"ccedil": "ç",
	"cedil": "¸",
	"cent": "¢",
	"copy": "©",
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
	"gt": ">",
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
	"lt": "<",
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
	"quot": "\"",
	"raquo": "»",
	"rdquo": "”",
	"reg": "®",
	"rsquo": "’",
	"sect": "§",
	"shy": stringWithValue(173),
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
	"nbsp": stringWithValue(160)
	]
