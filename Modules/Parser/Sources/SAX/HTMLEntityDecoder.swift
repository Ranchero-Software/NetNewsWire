//
//  HTMLEntityDecoder.swift
//
//
//  Created by Brent Simmons on 9/14/24.
//

import Foundation

public final class HTMLEntityDecoder {

	static let ampersandCharacter = Character("&")

	public static func decodedString(_ encodedString: String) -> String {

		let scanner = EntityScanner(string: encodedString)
		var result = ""
		var didDecodeAtLeastOneEntity = false

		while true {

			let scannedString = scanner.scanUpTo(Self.ampersandCharacter)
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

	/// Scans up to `characterToFind` and returns the characters up to (and not including) `characterToFind`.
	/// - Returns: the scanned portion before `characterToFind`. May be empty string.
	func scanUpTo(_ characterToFind: Character) -> String {

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
				scanLocation = initialScanLocation + 1
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

private func decodedEntity(_ rawEntity: String) -> String? {

	return nil
}
