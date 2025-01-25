//
//  HTMLEntityDecoder.swift
//
//
//  Created by Brent Simmons on 9/26/24.
//

import Foundation

public final class HTMLEntityDecoder {

	public static func decodedString(_ encodedString: String) -> String {

		var didDecodeAtLeastOneEntity = false

		// If `withContiguousStorageIfAvailable` works, then we can avoid copying memory.
		var result: String? = encodedString.utf8.withContiguousStorageIfAvailable { buffer in
			return decodedEntities(buffer, &didDecodeAtLeastOneEntity)
		}

		if result == nil {
			let d = Data(encodedString.utf8)
			result = d.withUnsafeBytes { bytes in
				let buffer = bytes.bindMemory(to: UInt8.self)
				return decodedEntities(buffer, &didDecodeAtLeastOneEntity)
			}
		}

		if let result {
			if didDecodeAtLeastOneEntity {
				return result
			}
			return encodedString
		}

		assertionFailure("Expected result but got nil.")
		return encodedString
	}
}

private let ampersandCharacter = Character("&").asciiValue!
private let numberSignCharacter = Character("#").asciiValue!
private let xCharacter = Character("x").asciiValue!
private let XCharacter = Character("X").asciiValue!
private let semicolonCharacter = Character(";").asciiValue!

private let zeroCharacter = Character("0").asciiValue!
private let nineCharacter = Character("9").asciiValue!
private let aCharacter = Character("a").asciiValue!
private let fCharacter = Character("f").asciiValue!
private let zCharacter = Character("z").asciiValue!
private let ACharacter = Character("A").asciiValue!
private let FCharacter = Character("F").asciiValue!
private let ZCharacter = Character("Z").asciiValue!

private let maxUnicodeNumber = 0x10FFFF

private func decodedEntities(_ sourceBuffer: UnsafeBufferPointer<UInt8>, _ didDecodeAtLeastOneEntity: inout Bool) -> String {

	let byteCount = sourceBuffer.count
	let resultBufferByteCount = byteCount + 1

	// Allocate a destination buffer for the result string. It can be the same size
	// as the source string buffer, since decoding HTML entities will only make it smaller.
	// Same size plus 1, that is, for null-termination.
	let resultBuffer = UnsafeMutableRawPointer.allocate(byteCount: resultBufferByteCount, alignment: MemoryLayout<UInt8>.alignment)
	defer {
		resultBuffer.deallocate()
	}

	resultBuffer.initializeMemory(as: UInt8.self, repeating: 0, count: resultBufferByteCount)
	let result = resultBuffer.assumingMemoryBound(to: UInt8.self)

	var sourceLocation = 0
	var resultLocation = 0

	while sourceLocation < byteCount {

		let ch = sourceBuffer[sourceLocation]

		var decodedEntity: String?

		if ch == ampersandCharacter {
			decodedEntity = decodedEntityValue(sourceBuffer, byteCount, &sourceLocation)
		}

		if let decodedEntity {
			addDecodedEntity(decodedEntity, result, byteCount, &resultLocation)
			didDecodeAtLeastOneEntity = true
			sourceLocation += 1
			continue
		}

		result[resultLocation] = ch

		resultLocation += 1
		sourceLocation += 1
	}

	let cString = resultBuffer.assumingMemoryBound(to: CChar.self)
	return String(cString: cString)
}

private func addDecodedEntity(_ decodedEntity: String, _ result: UnsafeMutablePointer<UInt8>, _ resultByteCount: Int, _ resultLocation: inout Int) {

	let utf8Bytes = Array(decodedEntity.utf8)
	precondition(resultLocation + utf8Bytes.count <= resultByteCount)

	for byte in utf8Bytes {
		result[resultLocation] = byte
		resultLocation += 1
	}
}

private func decodedEntityValue(_ buffer: UnsafeBufferPointer<UInt8>, _ byteCount: Int, _ sourceLocation: inout Int) -> String? {

	guard let rawEntity = rawEntityValue(buffer, byteCount, &sourceLocation) else {
		return nil
	}

	return decodedRawEntityValue(rawEntity)
}

private func decodedRawEntityValue(_ rawEntity: ContiguousArray<UInt8>) -> String? {

	var entityCharacters = [UInt8]()
	for character in rawEntity {
		if character == 0 {
			break
		}
		entityCharacters.append(character)
	}

	if let key = String(bytes: entityCharacters, encoding: .utf8) {
		if let entityString = entitiesDictionary[key] {
			return entityString
		}
	}

	if rawEntity[0] == numberSignCharacter {
		if let entityString = decodedNumericEntity(rawEntity) {
			return entityString
		}
	}

	return nil
}

private func decodedNumericEntity(_ rawEntity: ContiguousArray<UInt8>) -> String? {

	assert(rawEntity[0] == numberSignCharacter)

	var decodedNumber: UInt32?

	if rawEntity[1] == xCharacter || rawEntity[1] == XCharacter { // Hex?
		decodedNumber = decodedHexEntity(rawEntity)
	} else {
		decodedNumber = decodedDecimalEntity(rawEntity)
	}

	if let decodedNumber {
		return stringWithValue(decodedNumber)
	}
	return nil
}

private func decodedHexEntity(_ rawEntity: ContiguousArray<UInt8>) -> UInt32? {

	assert(rawEntity[0] == numberSignCharacter)
	assert(rawEntity[1] == xCharacter || rawEntity[1] == XCharacter)

	var number: UInt32 = 0
	var i = 0

	for byte in rawEntity {

		if i < 2 { // Skip first two characters: #x or #X
			i += 1
			continue
		}

		if byte == 0 { // rawEntity is null-terminated
			break
		}

		var digit: UInt32?

		switch byte {
		case zeroCharacter...nineCharacter: // 0-9
			digit = UInt32(byte - zeroCharacter)
		case aCharacter...fCharacter: // a-f
			digit = UInt32((byte - aCharacter) + 10)
		case ACharacter...FCharacter: // a-f
			digit = UInt32((byte - ACharacter) + 10)
		default:
			return nil
		}

		guard let digit else {
			return nil // Shouldn’t get here — handled by default case — but we need to bind digit
		}

		number = (number * 16) + digit
		if number > maxUnicodeNumber {
			return nil
		}
	}

	if number == 0 {
		return nil
	}

	return number
}

private func decodedDecimalEntity(_ rawEntity: ContiguousArray<UInt8>) -> UInt32? {

	assert(rawEntity[0] == numberSignCharacter)
	assert(rawEntity[1] != xCharacter && rawEntity[1] != XCharacter) // not hex

	var number: UInt32 = 0
	var isFirstCharacter = true

	// Convert, for instance, [51, 57] to 39
	for byte in rawEntity {

		if isFirstCharacter { // first character is #
			isFirstCharacter = false
			continue
		}

		if byte == 0 { // rawEntity is null-terminated
			break
		}

		// Be sure it’s a digit 0-9
		if byte < zeroCharacter || byte > nineCharacter {
			return nil
		}
		let digit = UInt32(byte - zeroCharacter)
		number = (number * 10) + digit
		if number > maxUnicodeNumber {
			return nil
		}
	}

	if number == 0 {
		return nil
	}

	return number
}

private func rawEntityValue(_ buffer: UnsafeBufferPointer<UInt8>, _ byteCount: Int, _ sourceLocation: inout Int) -> ContiguousArray<UInt8>? {

	// sourceLocation points to the & character.
	let savedSourceLocation = sourceLocation
	let maxEntityCharacters = 36 // Longest current entity is &CounterClockwiseContourIntegral;

	var entityCharacters: ContiguousArray<UInt8> = [0, 0, 0, 0, 0,
									 0, 0, 0, 0, 0,
									 0, 0, 0, 0, 0,
									 0, 0, 0, 0, 0, // 20 characters
									 0, 0, 0, 0, 0,
									 0, 0, 0, 0, 0,
									 0, 0, 0, 0, 0, // 35 characters
									 0] // nil-terminated last character

	var entityCharactersIndex = 0

	while true {

		sourceLocation += 1
		if sourceLocation >= byteCount || entityCharactersIndex >= maxEntityCharacters { // did not parse entity
			sourceLocation = savedSourceLocation
			return nil
		}

		let ch = buffer[sourceLocation]
		if ch == semicolonCharacter { // End of entity?
			return entityCharacters
		}

		// Make sure character is in 0-9, A-Z, a-z, #
		if ch < zeroCharacter && ch != numberSignCharacter {
			return nil
		}
		if ch > nineCharacter && ch < ACharacter {
			return nil
		}
		if ch > ZCharacter && ch < aCharacter {
			return nil
		}
		if ch > zCharacter {
			return nil
		}

		entityCharacters[entityCharactersIndex] = ch

		entityCharactersIndex += 1
	}
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

	if value >= 128 && value < 160 {
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
