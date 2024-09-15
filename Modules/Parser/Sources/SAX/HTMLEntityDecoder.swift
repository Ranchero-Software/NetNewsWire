//
//  HTMLEntityDecoder.swift
//
//
//  Created by Brent Simmons on 9/14/24.
//

import Foundation

public final class HTMLEntityDecoder {

	static func decodedString(withEncodedString encodedString: String) -> String {

		let scanner = Scanner(string: encodedString)
		scanner.charactersToBeSkipped = nil
		var result = ""
		var didDecodeAtLeastOneEntity = false

		while true {

			var scannedString: NSString? = nil
			if scanner.scanUpTo("&", into: &scannedString) {
				result.append(scannedString)
			}
			if scanner.isAtEnd {
				break
			}

			let savedScanLocation = scanner.scanLocation

			var decodedEntity: String? = nil
			if scanner.scanEntityValue(&decodedEntity) {
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

		if !didDecodeAtLeastOneEntity { // No changes made?
			return encodedString
		}
		return result
	}
}

/// Purpose-built version of NSScanner, which has deprecated the parts we want to use.
final class RSScanner {

	let string: String
	let count: Int
	var scanLocation = 0

	var isAtEnd {
		scanLocation >= count - 1
	}

	init(string: String) {
		self.string = string
		self.count = string.count
	}

	/// Scans up to `characterToFind` and returns the characters up to (and not including) `characterToFind`.
	/// - Returns: nil when there were no characters accumulated (next character was `characterToFind` or already at end of string)
	func scanUpTo(_ characterToFind: Character) -> String? {

		if isAtEnd {
			return nil
		}

		while true {


		}
	}

	private func currentCharacter() -> Character? {



	}

	private func 

}
